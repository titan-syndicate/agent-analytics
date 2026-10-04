#!/usr/bin/env python3
"""Local-only lab launcher and end-to-end storage checks (standard library only)."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import uuid
from collections import Counter
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


GRAFANA = "http://127.0.0.1:3000"
OTLP = "http://127.0.0.1:4318"
SERVICE = "github-copilot-local"
CONTENT_KEYS = {
    "gen_ai.input.messages",
    "gen_ai.output.messages",
    "gen_ai.system_instructions",
    "gen_ai.tool.definitions",
    "gen_ai.tool.call.arguments",
    "gen_ai.tool.call.result",
}


def request_json(url, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(url, data=data, headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def proxy(source, path, params=None):
    url = f"{GRAFANA}/api/datasources/proxy/uid/{source}/{path}"
    if params:
        url += "?" + urlencode(params)
    return request_json(url)


def wait_for(description, check, timeout):
    deadline = time.monotonic() + timeout
    last_error = "no matching data yet"
    while True:
        try:
            value = check()
            if value:
                return value
        except HTTPError as error:
            # A just-exported trace may not yet be readable; other HTTP errors are real failures.
            if error.code != 404:
                raise
            last_error = "not yet stored (HTTP 404)"
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Timed out waiting for {description}: {last_error}")
        time.sleep(2)


def trace_spans(trace):
    # Tempo versions use either OTLP resourceSpans or the legacy batches key.
    groups = trace.get("resourceSpans", trace.get("batches", []))
    for group in groups:
        scopes = group.get("scopeSpans", group.get("instrumentationLibrarySpans", []))
        for scope in scopes:
            yield from scope.get("spans", [])


def attributes(span):
    return {item["key"]: item["value"] for item in span.get("attributes", [])}


def string_attribute(span, key):
    return attributes(span).get(key, {}).get("stringValue")


def content_keys(record):
    found = set()
    if isinstance(record, dict):
        if isinstance(record.get("key"), str) and record["key"] in CONTENT_KEYS:
            found.add(record["key"])
        found.update(CONTENT_KEYS.intersection(record))
        for value in record.values():
            found.update(content_keys(value))
    elif isinstance(record, list):
        for value in record:
            found.update(content_keys(value))
    return found


def recent_metrics(since):
    # timestamp() drops __name__; preserve it on a temporary query label first.
    selector = '{__name__=~"(gen_ai|github_copilot).*",service_name="' + SERVICE + '"}'
    query = (
        'timestamp(label_replace(' + selector
        + ', "agent_analytics_metric_name", "$1", "__name__", "(.+)"))'
    )
    result = proxy("prometheus", "api/v1/query_range", {
        "query": query,
        "start": since,
        "end": int(time.time()) + 1,
        "step": 30,
    })
    if result.get("status") != "success":
        raise RuntimeError("Prometheus query failed")
    return [
        item for item in result["data"]["result"]
        if any(float(value[1]) >= since for value in item["values"])
    ]


def require_health():
    if request_json(f"{GRAFANA}/api/health").get("database") != "ok":
        raise RuntimeError("Grafana database is not healthy")


def smoke(timeout):
    require_health()
    trace_id = uuid.uuid4().hex
    span_id = uuid.uuid4().hex[:16]
    now = time.time_ns()
    response = request_json(
        f"{OTLP}/v1/traces",
        {
            "resourceSpans": [{
                "resource": {"attributes": [{
                    "key": "service.name",
                    "value": {"stringValue": "agent-analytics-smoke"},
                }]},
                "scopeSpans": [{
                    "scope": {"name": "agent-analytics-probe"},
                    "spans": [{
                        "traceId": trace_id,
                        "spanId": span_id,
                        "name": "invoke_agent smoke",
                        "kind": 1,
                        "startTimeUnixNano": str(now - 1_000_000),
                        "endTimeUnixNano": str(now),
                        "attributes": [{
                            "key": "gen_ai.operation.name",
                            "value": {"stringValue": "invoke_agent"},
                        }],
                        "status": {"code": 1},
                    }],
                }],
            }],
        },
    )
    if response.get("partialSuccess"):
        raise RuntimeError("OTLP receiver reported partialSuccess; inspect collector logs")
    trace = wait_for(
        "synthetic trace read-back",
        lambda: proxy("tempo", f"api/traces/{trace_id}"),
        timeout,
    )
    if len(list(trace_spans(trace))) != 1:
        raise RuntimeError("Synthetic trace did not contain exactly one span")
    print(json.dumps({"synthetic_trace": "stored", "trace_id": trace_id, "viewer": GRAFANA}))


def local_environment(environ):
    env = {
        key: value for key, value in environ.items()
        if not key.startswith(("OTEL_", "COPILOT_OTEL_"))
    }
    env.update({
        "COPILOT_OTEL_ENABLED": "true",
        "COPILOT_OTEL_EXPORTER_TYPE": "otlp-http",
        "OTEL_EXPORTER_OTLP_ENDPOINT": OTLP,
        "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
        "OTEL_SERVICE_NAME": SERVICE,
        "OTEL_RESOURCE_ATTRIBUTES":
            "deployment.environment.name=local,agent_analytics.client_surface=cli",
        "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT": "false",
    })
    return env


def run_copilot(args):
    if shutil.which("copilot") is None:
        raise RuntimeError("copilot is not installed; use the approved CLI installer")
    if any("remote-export" in arg for arg in args):
        raise RuntimeError("This lab disables session syncing; omit remote-export flags")
    require_health()
    print(
        f"Local metadata export -> {OTLP}; content off; session syncing off. "
        "Enterprise-managed telemetry settings can override local configuration.",
        file=sys.stderr,
        flush=True,
    )
    os.execvpe("copilot", ["copilot", "--no-remote-export", *args], local_environment(os.environ))


def verify_copilot(since, timeout, expected_traces):
    require_health()
    seen = {}

    def traces_ready():
        result = proxy("tempo", "api/search", {
            "q": '{ resource.service.name = "' + SERVICE + '" }',
            "start": since,
            "end": int(time.time()) + 1,
            "limit": 100,
        })
        for item in result.get("traces", []):
            trace_id = item["traceID"]
            trace = proxy("tempo", f"api/traces/{trace_id}")
            if content_keys(trace):
                raise RuntimeError("Known content attributes found; stop capture and inspect privately")
            seen[trace_id] = list(trace_spans(trace))
        operations = Counter(
            string_attribute(span, "gen_ai.operation.name")
            for spans in seen.values() for span in spans
        )
        return (
            len(seen) >= expected_traces
            and all(operations[name] > 0 for name in ("invoke_agent", "chat", "execute_tool"))
        )

    wait_for("Copilot invocation, chat and tool spans", traces_ready, timeout)
    # Verify actual CLI metric samples, not just metric names from an older session.
    def metrics_ready():
        metrics = recent_metrics(since)
        names = {item["metric"]["agent_analytics_metric_name"] for item in metrics}
        required = {
            "gen_ai_client_inference_usage_input_tokens_total",
            "gen_ai_client_inference_usage_output_tokens_total",
            "github_copilot_tool_call_count_total",
        }
        return metrics if required.issubset(names) else None

    metrics = wait_for("Copilot metrics", metrics_ready, timeout)
    names = sorted({item["metric"]["agent_analytics_metric_name"] for item in metrics})
    spans = [span for group in seen.values() for span in group]
    operations = Counter(string_attribute(span, "gen_ai.operation.name") for span in spans)
    models = sorted({
        string_attribute(span, "gen_ai.response.model")
        or string_attribute(span, "gen_ai.request.model")
        for span in spans
        if string_attribute(span, "gen_ai.operation.name") == "chat"
    } - {None})
    print(json.dumps({
        "trace_count": len(seen),
        "operations": dict(operations),
        "models": models,
        "metric_names": names,
        "known_content_fields": "absent in retrieved traces",
        "trace_ids": sorted(seen),
        "viewer": f"{GRAFANA}/explore",
    }, indent=2))


def doctor():
    for tool in ("docker", "kubectl", "tilt", "copilot"):
        if shutil.which(tool) is None:
            raise RuntimeError(f"Missing prerequisite: {tool}")
    context = subprocess.check_output(
        ["kubectl", "config", "current-context"], text=True
    ).strip()
    if context != "docker-desktop":
        raise RuntimeError(f"Expected docker-desktop context, found {context}; no context was changed")
    subprocess.run(["docker", "info", "--format", "{{.ServerVersion}}"], check=True)
    subprocess.run(["kubectl", "--context", context, "get", "nodes"], check=True)
    for tool in ("tilt", "copilot"):
        subprocess.run([tool, "version"], check=True)
    print("Prerequisites ready. Check ports 3000, 4318 and 10350 before starting Tilt.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor")
    smoke_parser = commands.add_parser("smoke")
    smoke_parser.add_argument("--timeout", type=int, default=120)
    run_parser = commands.add_parser("run")
    run_parser.add_argument("args", nargs=argparse.REMAINDER)
    verify_parser = commands.add_parser("verify-copilot")
    verify_parser.add_argument("--since", type=int, required=True, help="Unix seconds before CLI tasks")
    verify_parser.add_argument("--timeout", type=int, default=120)
    verify_parser.add_argument("--expected-traces", type=int, default=1)
    args = parser.parse_args()
    if getattr(args, "timeout", 1) <= 0:
        parser.error("--timeout must be positive")
    if getattr(args, "expected_traces", 1) <= 0:
        parser.error("--expected-traces must be positive")
    if args.command == "verify-copilot" and not 0 <= args.since <= int(time.time()):
        parser.error("--since must be a past Unix timestamp in seconds")
    try:
        if args.command == "doctor":
            doctor()
        elif args.command == "smoke":
            smoke(args.timeout)
        elif args.command == "run":
            cli_args = args.args[1:] if args.args[:1] == ["--"] else args.args
            run_copilot(cli_args)
        else:
            verify_copilot(args.since, args.timeout, args.expected_traces)
    except HTTPError as error:
        detail = error.read(4096).decode("utf-8", errors="replace").strip()
        print(f"Lab check failed: HTTP {error.code} {error.reason}: {detail}", file=sys.stderr)
        return 1
    except (URLError, OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Lab check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
