import importlib.util
import io
import unittest
from pathlib import Path
from urllib.error import HTTPError
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "lab", Path(__file__).resolve().parents[1] / "scripts" / "lab.py"
)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


class LabTests(unittest.TestCase):
    def test_environment_replaces_all_otel_overrides_but_preserves_auth(self):
        env = lab.local_environment({
            "PATH": "/usr/bin",
            "GH_TOKEN": "synthetic-auth",
            "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT": "https://example.invalid",
            "OTEL_EXPORTER_OTLP_HEADERS": "secret-header",
            "OTEL_EXPORTER_OTLP_CLIENT_KEY": "private-key-path",
            "OTEL_RESOURCE_ATTRIBUTES": "enduser.id=someone",
            "COPILOT_OTEL_FILE_EXPORTER_PATH": "private-history.jsonl",
            "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT": "true",
        })
        self.assertEqual(env["GH_TOKEN"], "synthetic-auth")
        self.assertEqual(env["OTEL_EXPORTER_OTLP_ENDPOINT"], lab.OTLP)
        self.assertEqual(env["OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"], "false")
        self.assertNotIn("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", env)
        self.assertNotIn("OTEL_EXPORTER_OTLP_CLIENT_KEY", env)
        self.assertNotIn("COPILOT_OTEL_FILE_EXPORTER_PATH", env)

    def test_known_content_is_detected_in_resource_and_span_events(self):
        record = {"resourceSpans": [{
            "resource": {"attributes": [{"key": "gen_ai.input.messages", "value": {}}]},
            "scopeSpans": [{"spans": [{"events": [{
                "attributes": [{"key": "gen_ai.tool.call.result", "value": {}}]
            }]}]}],
        }]}
        self.assertEqual(lab.content_keys(record), {
            "gen_ai.input.messages", "gen_ai.tool.call.result"
        })
        self.assertEqual(lab.content_keys({"ordinary": [{"key": "service.name"}]}), set())
        self.assertEqual(lab.content_keys({"key": {"nested": "metadata"}}), set())

    def test_current_and_legacy_tempo_trace_shapes(self):
        span = {"name": "synthetic"}
        self.assertEqual(list(lab.trace_spans({
            "resourceSpans": [{"scopeSpans": [{"spans": [span]}]}]
        })), [span])
        self.assertEqual(list(lab.trace_spans({
            "batches": [{"instrumentationLibrarySpans": [{"spans": [span]}]}]
        })), [span])

    def test_wait_fails_explicitly_instead_of_returning_success(self):
        with patch.object(lab.time, "monotonic", side_effect=[0, 2]):
            with self.assertRaisesRegex(RuntimeError, "Timed out"):
                lab.wait_for("missing telemetry", lambda: None, 1)

    def test_metrics_use_sample_timestamp_not_query_evaluation_timestamp(self):
        old = {"metric": {"agent_analytics_metric_name": "gen_ai_old"}, "values": [[200, "90"]]}
        recent = {"metric": {"agent_analytics_metric_name": "gen_ai_recent"}, "values": [[200, "110"]]}
        response = {"status": "success", "data": {"result": [old, recent]}}
        with patch.object(lab, "proxy", return_value=response) as proxy:
            self.assertEqual(lab.recent_metrics(100), [recent])
            query = proxy.call_args[0][2]["query"]
            self.assertIn("timestamp(label_replace(", query)
            self.assertIn('service_name="github-copilot-local"', query)

    def test_failed_metrics_query_is_not_reported_as_empty_success(self):
        with patch.object(lab, "proxy", return_value={"status": "error"}):
            with self.assertRaisesRegex(RuntimeError, "Prometheus query failed"):
                lab.recent_metrics(100)

    def test_remote_export_cannot_be_enabled_by_wrapper_arguments(self):
        with patch.object(lab.shutil, "which", return_value="/synthetic/copilot"):
            with self.assertRaisesRegex(RuntimeError, "disables session syncing"):
                lab.run_copilot(["--remote-export"])

    def test_http_failure_includes_backend_diagnostic(self):
        error = HTTPError(lab.GRAFANA, 400, "Bad Request", {}, io.BytesIO(b"invalid query"))
        stderr = io.StringIO()
        with patch.object(lab.sys, "argv", ["lab.py", "smoke"]), \
                patch.object(lab, "smoke", side_effect=error), \
                patch.object(lab.sys, "stderr", stderr):
            self.assertEqual(lab.main(), 1)
        self.assertIn("HTTP 400 Bad Request: invalid query", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
