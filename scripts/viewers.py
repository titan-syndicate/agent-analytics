#!/usr/bin/env python3
"""Read the same trace back from all three local viewers (stdlib only)."""

import argparse
import base64
import json
from pathlib import Path
from datetime import datetime
import re
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import uuid

import lab


ROOT = Path(__file__).resolve().parents[1]
KINDS = {
    "invoke_agent": ("AGENT", "AGENT"),
    "chat": ("LLM", "GENERATION"),
    "execute_tool": ("TOOL", "TOOL"),
}


def fetch(url, headers=None):
    with urlopen(Request(url, headers=headers or {}), timeout=10) as response:
        return json.load(response)


def synthetic_trace():
    trace_id = uuid.uuid4().hex
    parent = uuid.uuid4().hex[:16]
    now = time.time_ns()
    spans = []
    for index, operation in enumerate(KINDS):
        attrs = {
            "gen_ai.operation.name": {"stringValue": operation},
            "gen_ai.conversation.id": {"stringValue": "synthetic-" + trace_id},
        }
        if operation == "chat":
            attrs.update({
                "gen_ai.request.model": {"stringValue": "synthetic-model"},
                "gen_ai.usage.input_tokens": {"intValue": "12"},
                "gen_ai.usage.output_tokens": {"intValue": "3"},
            })
        span = {
            "traceId": trace_id,
            "spanId": parent if index == 0 else uuid.uuid4().hex[:16],
            "name": operation + " comparison-smoke", "kind": 1,
            "startTimeUnixNano": str(now - 10_000_000 + index * 1_000_000),
            "endTimeUnixNano": str(now),
            "status": {"code": 1},
            "attributes": [{"key": key, "value": value} for key, value in attrs.items()],
        }
        if index:
            span["parentSpanId"] = parent
        spans.append(span)
    return trace_id, {"resourceSpans": [{
        "resource": {"attributes": [{"key": "service.name",
                                    "value": {"stringValue": "agent-viewer-smoke"}}]},
        "scopeSpans": [{"scope": {"name": "viewer-comparison"}, "spans": spans}],
    }]}


def otlp_id(value):
    if re.fullmatch(r"[0-9a-f]+", value):
        return value
    return base64.b64decode(value).hex()


def check_model_usage(span, phoenix, langfuse):
    source = lab.attributes(span)
    model = lab.string_attribute(span, "gen_ai.response.model") or lab.string_attribute(
        span, "gen_ai.request.model")
    if model and (phoenix["attributes"].get("llm.model_name") != model
                  or langfuse.get("model") != model):
        raise RuntimeError("Viewer model does not match source")
    usage = langfuse.get("usageDetails", {})
    for key, phoenix_key, langfuse_keys in (
        ("gen_ai.usage.input_tokens", "llm.token_count.prompt",
         ("input", "input_cached_tokens", "input_cache_creation")),
        ("gen_ai.usage.output_tokens", "llm.token_count.completion", ("output",)),
    ):
        if key not in source:
            continue
        expected = int(source[key]["intValue"])
        if phoenix["attributes"].get(phoenix_key) != expected:
            raise RuntimeError("Phoenix token count does not match source")
        if sum(usage.get(name, 0) for name in langfuse_keys) != expected:
            raise RuntimeError("Langfuse cache-normalized token count does not match source")


def metadata_only_output(span, output):
    if not output:
        return True
    # Phoenix's GenAI conversion synthesizes a response envelope, not message content.
    value = json.loads(output) if isinstance(output, str) else output
    expected = {
        "id": lab.string_attribute(span, "gen_ai.response.id"),
        "model": lab.string_attribute(span, "gen_ai.response.model"),
    }
    return isinstance(value, dict) and all(
        key in expected and expected[key] is not None and expected[key] == item
        for key, item in value.items()
    )


def verify(trace_id, timeout):
    keys = json.loads((ROOT / ".local-lab" / "credentials.json").read_text())
    headers = {"Authorization": "Basic " + keys["LANGFUSE_AUTH"]}
    raw = lab.wait_for("Tempo trace", lambda: lab.proxy(
        "tempo", "api/traces/" + trace_id), timeout)
    raw_spans = list(lab.trace_spans(raw))
    expected = {otlp_id(span["spanId"]): span for span in raw_spans}
    if not expected:
        raise RuntimeError("Tempo returned no spans")
    if lab.content_keys(raw):
        raise RuntimeError("Known GenAI content fields detected; inspect privately")

    def phoenix_ready():
        result = fetch("http://127.0.0.1:6006/v1/projects/copilot-lab/spans?"
                       + urlencode({"trace_id": trace_id, "limit": 1000}))["data"]
        found = {span["context"]["span_id"]: span for span in result}
        return found if expected.keys() <= found.keys() else None

    def langfuse_ready():
        result = fetch("http://127.0.0.1:3001/api/public/v2/observations?"
                       + urlencode({"traceId": trace_id, "limit": 1000,
                                    "fields": "core,basic,time,io,model,usage,metadata,trace_context"}),
                       headers)["data"]
        found = {span["id"]: span for span in result}
        return found if expected.keys() <= found.keys() else None

    phoenix = lab.wait_for("Phoenix matching span IDs", phoenix_ready, timeout)
    langfuse = lab.wait_for("Langfuse matching observation IDs", langfuse_ready, timeout)
    operations = {}
    for span_id, span in expected.items():
        operation = lab.string_attribute(span, "gen_ai.operation.name")
        operations[operation] = operations.get(operation, 0) + 1
        if operation not in KINDS:
            continue
        phoenix_span, langfuse_span = phoenix[span_id], langfuse[span_id]
        if phoenix_span["context"]["trace_id"] != trace_id or langfuse_span["traceId"] != trace_id:
            raise RuntimeError("Viewer trace identity changed")
        if (phoenix_span["span_kind"], langfuse_span["type"].upper()) != KINDS[operation]:
            raise RuntimeError("Viewer operation kind does not match source")
        parent = otlp_id(span["parentSpanId"]) if span.get("parentSpanId") else None
        if phoenix_span.get("parent_id") != parent or langfuse_span.get("parentObservationId") != parent:
            raise RuntimeError("Viewer parent relationship does not match source")
        session = lab.string_attribute(span, "gen_ai.conversation.id")
        if session and (phoenix_span["attributes"].get("session.id") != session
                        or langfuse_span.get("sessionId") != session):
            raise RuntimeError("Viewer session identity does not match source")
        if phoenix_span["attributes"].get("input.value") \
                or not metadata_only_output(span, phoenix_span["attributes"].get("output.value")) \
                or langfuse_span.get("input") or langfuse_span.get("output"):
            raise RuntimeError("Unexpected content in viewer input/output fields")
        for source_key, phoenix_key, langfuse_key in (
            ("startTimeUnixNano", "start_time", "startTime"),
            ("endTimeUnixNano", "end_time", "endTime"),
        ):
            original = int(span[source_key])
            for value in (phoenix_span[phoenix_key], langfuse_span[langfuse_key]):
                actual = datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1e9
                if abs(actual - original) > 1_000_000:
                    raise RuntimeError("Viewer timestamp differs by more than one millisecond")
        if operation == "chat":
            check_model_usage(span, phoenix_span, langfuse_span)
    print(json.dumps({
        "trace_id": trace_id, "matching_spans": len(expected), "operations": operations,
        "identity_parent_kind_time_session_and_usage_checks": "passed",
        "viewers": ["http://127.0.0.1:6006", "http://127.0.0.1:3001",
                    "http://127.0.0.1:3000/explore"],
    }, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    smoke = commands.add_parser("smoke")
    smoke.add_argument("--timeout", type=int, default=180)
    check = commands.add_parser("verify")
    check.add_argument("--trace-id", required=True)
    check.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.command == "verify" and not re.fullmatch(r"[0-9a-f]{32}", args.trace_id):
        parser.error("--trace-id must be a 32-character lowercase hex ID")
    try:
        if args.command == "smoke":
            trace_id, payload = synthetic_trace()
            receipt = ROOT / ".local-lab" / "last-probe.json"
            receipt.write_text(json.dumps({"trace_id": trace_id}))
            response = lab.request_json(lab.OTLP + "/v1/traces", payload)
            if response.get("partialSuccess"):
                raise RuntimeError("Collector rejected part of the synthetic trace")
        else:
            trace_id = args.trace_id
        verify(trace_id, args.timeout)
    except HTTPError as error:
        detail = error.read(4096).decode(errors="replace")
        print(f"Viewer check failed: HTTP {error.code}: {detail}", file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f"Viewer check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
