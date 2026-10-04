# Sources, scope and verification

**Research checked: October 4, 2026.** Product documentation is live and may change. These sources support capability claims; the proposals and pilot thresholds are our recommendations, not upstream guarantees.

## Source register

| Topic | Primary reference | Used for |
| --- | --- | --- |
| Copilot CLI telemetry | [CLI command reference: OpenTelemetry monitoring](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#opentelemetry-monitoring) | Environment variables, traces, metrics, events, content and billing units |
| CLI installation | [Install Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/install-copilot-cli) | Prerequisites and supported install paths |
| Runtime changes | [Official CLI changelog](https://github.com/github/copilot-cli/blob/main/changelog.md) | Cache field renaming, compaction fields, protocol support and hook trace context |
| Cross-client OTel | [OpenTelemetry for agent monitoring](https://docs.github.com/en/copilot/concepts/enterprise/opentelemetry) | Conceptual traces/metrics/events and optional content |
| Managed settings | [Enterprise managed settings](https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings) | Supported client matrix and telemetry schema |
| SDK telemetry | [OpenTelemetry instrumentation for Copilot SDK](https://docs.github.com/en/copilot/how-tos/copilot-sdk/observability/opentelemetry) | Explicit SDK telemetry configuration and W3C trace context |
| Desktop customization | [Customizing the Copilot app](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app) | Skills/plugins are available; not proof of telemetry environment propagation |
| Local app/CLI history | [About Copilot session data](https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/session-data) | Shared local session directory, SQLite subset, syncing and history queries' model-data boundary |
| On-disk layout | [CLI configuration directory](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference#session-state) | `events.jsonl`, `session-store.db`, configuration root and managed-file cautions |
| Built-in history insights | [Using CLI session data](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/chronicle) | `/chronicle` commands, usage insights, reindex/sync and index path |
| Desktop history integration | [Working with app sessions](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions#using-chronicle-with-app-sessions) | App explicitly supports CLI history features such as `/chronicle` |
| Session event semantics | [SDK streaming events reference](https://github.com/github/copilot-sdk/blob/main/docs/features/streaming-events.md) | Envelope, tool pairing, previous-event parent IDs and ephemeral usage; not a stable desktop disk-schema guarantee |
| GenAI semantics | [Current GenAI semantic conventions repository](https://github.com/open-telemetry/semantic-conventions-genai/tree/main/docs/gen-ai) | Development status and signal definitions |
| OTel components | [Collector documentation](https://opentelemetry.io/docs/collector/) | Receive/process/export boundary, operational configuration |
| Local backend | [Grafana Docker LGTM guide](https://grafana.com/docs/opentelemetry/docker-lgtm/) | Development-only image, endpoints, Kubernetes route and persistence guidance |
| LGTM Kubernetes | [Upstream Kubernetes manifest](https://github.com/grafana/docker-otel-lgtm/blob/main/k8s/lgtm.yaml) | Readiness and example deployment shape |
| Tilt API | [Tiltfile API](https://docs.tilt.dev/api.html) | Kubernetes resources, loopback forwarding and context checks |
| Phoenix deployment | [Self-hosting Phoenix](https://arize.com/docs/phoenix/self-hosting) | Local deployment, storage choices and evaluation capabilities |
| Phoenix semantics | [OpenInference best practices](https://arize.com/docs/phoenix/cookbook/tracing/openinference-best-practices) | AI-aware operation kinds/session semantics; mapping must be tested for Copilot |
| Langfuse ingest | [Native OpenTelemetry integration](https://langfuse.com/integrations/native/opentelemetry) | HTTP protocols, GenAI mapping, session fields, v4 ingestion header |
| Langfuse deployment | [Self-hosted Docker Compose](https://langfuse.com/self-hosting/deployment/docker-compose) | Local infrastructure requirements and initialization |
| Honeycomb ingest | [Send data with the Collector](https://docs.honeycomb.io/send-data/opentelemetry/collector) | OTLP protocols, region endpoints, headers and metrics dataset requirement |
| Honeycomb agent semantics | [Instrumenting AI agents](https://docs.honeycomb.io/send-data/use-cases/agents) | Conversation, agent, operation, usage and optional context fields |
| Honeycomb UI | [Agent Timeline](https://docs.honeycomb.io/investigate/observe/agent-timeline) | Conversation navigation, frames, unknown agents and early-access insights |
| OpenSearch APM | [APM overview](https://docs.opensearch.org/latest/observing-your-data/apm/index/) | APM introduced in 3.6; separate from older analytics |
| OpenSearch pipeline | [Configuring telemetry ingestion](https://docs.opensearch.org/latest/observing-your-data/apm/configuring-telemetry-ingestion/) | Collector/Data Prepper/OpenSearch/Prometheus architecture |
| Data Prepper OTLP | [Unified OTLP source](https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/sources/otlp-source/) | Protocol, port and path differences |
| AIOps | [IBM AIOps overview](https://www.ibm.com/think/topics/aiops) | Conventional AI-for-IT-operations framing |
| FinOps | [What is FinOps?](https://www.finops.org/introduction/what-is-finops/) | Technology value, shared ownership and cost discipline |
| Delivery outcomes | [DORA metrics guide](https://dora.dev/guides/dora-metrics/) | Outcome context and comparison pitfalls |
| Developer productivity | [The SPACE of Developer Productivity](https://queue.acm.org/detail.cfm?id=3454124) | Multidimensional framework; publisher blocked automated retrieval during this research |
| Pages | [What is GitHub Pages?](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages) | Static publication and project-site URL |

## Important qualifications

**Desktop is not verified.** The managed settings matrix marks `telemetry` unsupported in the app. A CLI-derived local runtime may behave differently, but this needs a real app/version/surface experiment. The guide deliberately does not invent an app setting.

**Local history is a documented fallback, not native OTel.** GitHub documents saved app/CLI records and `/chronicle` integration. The importer remains proposed and has not been tested against private local files. The SDK marks per-call `assistant.usage` ephemeral, so persistence and aggregation coverage cannot be assumed.

**GenAI conventions are not frozen.** The current OTel page redirects readers to the new GenAI conventions repository, which marks the work Development. Runtime/schema-version fixtures are essential.

**“Cost” is not currency.** GitHub's CLI reference says `github.copilot.cost` is a model multiplier and documents `github.copilot.nano_aiu` as AI units. Both require careful grain and billing interpretation.

**Agent frames are conditional.** Honeycomb documents the display, but content capture, attributes and parser compatibility must line up. No full-context access is guaranteed simply by setting an endpoint.

**OpenSearch versions matter.** The current APM pages describe 3.6-era architecture. Your organization's cluster may run an older version with a different feature set and pipeline.

## What has not been validated here

The [October 4 experiment](../experiments/cli-local-otel.md) now verifies the native CLI-to-local-LGTM path: synthetic read-back, two CLI tasks, model/tool spans, Prometheus metrics, and absence of known GenAI content keys. A small CLI helper is implemented; it is not the proposed packaged installer.

This publication does not claim a desktop export test, Honeycomb ingestion using a real key, OpenSearch/Phoenix/Langfuse ingestion, a session-history importer, an installable skill, or tested telemetry retention.

The docs build validates the static site's structure and internal links. It does not prove the compatibility of every external product, every code sample, or your enterprise policy.

## Before implementing the proposals

Record exact client/app/backend/collector versions; run synthetic ingestion and read-back; capture a safe real task; inspect privacy; test duplicate/missing spans and billing aggregation; then publish a private compatibility result. Update the source register and caveats when claims change.
