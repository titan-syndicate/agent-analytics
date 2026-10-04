import importlib.util
import io
from datetime import datetime, timezone
from pathlib import Path
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("lab", ROOT / "scripts" / "lab.py")
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)
spec = importlib.util.spec_from_file_location("viewers", ROOT / "scripts" / "viewers.py")
viewers = importlib.util.module_from_spec(spec)
with patch.dict("sys.modules", {"lab": lab}):
    spec.loader.exec_module(viewers)


class ViewerTests(unittest.TestCase):
    def test_fixture_has_one_shared_trace_and_three_parented_operations(self):
        trace_id, payload = viewers.synthetic_trace()
        spans = list(lab.trace_spans(payload))
        self.assertEqual(len(spans), 3)
        self.assertEqual({span["traceId"] for span in spans}, {trace_id})
        self.assertEqual([lab.string_attribute(span, "gen_ai.operation.name") for span in spans],
                         ["invoke_agent", "chat", "execute_tool"])
        self.assertTrue(all(span["parentSpanId"] == spans[0]["spanId"] for span in spans[1:]))
        self.assertFalse(lab.content_keys(payload))

    def check_fixture(self, wrong_parent=False):
        trace_id, payload = viewers.synthetic_trace()
        spans = list(lab.trace_spans(payload))
        phoenix, langfuse = {}, {}
        for span in spans:
            operation = lab.string_attribute(span, "gen_ai.operation.name")
            sid = span["spanId"]
            parent = span.get("parentSpanId")
            phoenix[sid] = {
                "context": {"trace_id": trace_id}, "span_kind": viewers.KINDS[operation][0],
                "parent_id": parent,
                "attributes": {
                    "session.id": lab.string_attribute(span, "gen_ai.conversation.id"),
                },
            }
            langfuse[sid] = {
                "traceId": trace_id, "type": viewers.KINDS[operation][1],
                "parentObservationId": "wrong" if wrong_parent else parent,
                "sessionId": lab.string_attribute(span, "gen_ai.conversation.id"),
            }
            for source_key, pkey, lkey in (
                ("startTimeUnixNano", "start_time", "startTime"),
                ("endTimeUnixNano", "end_time", "endTime"),
            ):
                value = datetime.fromtimestamp(int(span[source_key]) / 1e9, timezone.utc).isoformat()
                phoenix[sid][pkey] = langfuse[sid][lkey] = value
            if operation == "chat":
                phoenix[sid]["attributes"].update({
                    "llm.model_name": "synthetic-model",
                    "llm.token_count.prompt": 12, "llm.token_count.completion": 3,
                })
                langfuse[sid].update({
                    "model": "synthetic-model", "usageDetails": {
                        "input": 2, "input_cached_tokens": 8, "input_cache_creation": 2, "output": 3,
                    },
                })
        with patch.object(Path, "read_text", return_value='{"LANGFUSE_AUTH": "synthetic"}'), \
                patch.object(lab, "wait_for", side_effect=[payload, phoenix, langfuse]), \
                patch.object(viewers.sys, "stdout", io.StringIO()):
            viewers.verify(trace_id, 1)

    def test_matching_identity_parent_and_operation_kinds_pass(self):
        self.check_fixture()

    def test_changed_parent_is_a_failure(self):
        with self.assertRaisesRegex(RuntimeError, "parent relationship"):
            self.check_fixture(wrong_parent=True)

    def test_tempo_base64_ids_are_normalized(self):
        self.assertEqual(viewers.otlp_id("EjRWeJCrze8="), "1234567890abcdef")

    def test_phoenix_response_envelope_cannot_hide_message_content(self):
        span = {"attributes": [
            {"key": "gen_ai.response.id", "value": {"stringValue": "synthetic-id"}},
            {"key": "gen_ai.response.model", "value": {"stringValue": "synthetic-model"}},
        ]}
        self.assertTrue(viewers.metadata_only_output(
            span, '{"id":"synthetic-id","model":"synthetic-model"}'))
        self.assertFalse(viewers.metadata_only_output(
            span, '{"id":"synthetic-id","text":"unexpected content"}'))


if __name__ == "__main__":
    unittest.main()
