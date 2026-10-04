# Privacy and trust are part of the design

**Default to metadata-only, local-only, opt-in collection.** Agent context can contain proprietary code, credentials, personal information, customer data and instructions from untrusted sources. “Local” reduces exposure but does not make capture harmless.

This page is a proposed data policy, not a claim that the lab image enforces it. Obtain your organization's security, privacy, employment and legal review before broad deployment.

## Proposed capture tiers

| Tier | Data | Default and sharing |
| --- | --- | --- |
| 0: Off | No agent analytics export | Available opt-out; respect enforced organizational policy |
| 1: Structure | Operation/model/tool categories, timing, counts, status, random IDs | Pilot default; stays local |
| 2: Sanitized summaries | Task class, coarse outcome, usage totals, tooling version, coverage | Optional approved central export |
| 3: Detailed content | Messages, code, instructions, tool arguments/results | Exceptional, session-scoped and explicitly approved |

Even structure can reveal work habits, file paths or identifying metadata. `enduser.pseudo.id` is linkable, skill events can include paths, and exception messages can contain tool output. Review every retained field.

## Enforce at the boundary

Client switches are convenient, not an enforcement layer. The proposed collector gateway should allowlist metadata fields and remove content before persistent queues, backend storage or external exporters.

Cover resource attributes, span attributes, span names, span events and their attributes, log bodies, metric datapoint attributes and any opaque nested payload. Unknown fields are denied for shared/exported metadata until reviewed. Content can hide under arbitrary vendor keys; deleting six known GenAI fields is not a complete policy.

Normalize error categories rather than preserving arbitrary exception text. Replace raw paths and repository identifiers with approved coarse categories or local random IDs. Avoid deterministic hashes of emails/paths: they are often guessable and still linkable.

A regex “secret scrubber” is defense in depth, not permission to collect everything. Prefer never collecting the sensitive content in the first place.

## Proposed retention and storage

Start with seven days of raw metadata and thirty days of content-free summaries. If content is exceptionally captured, expire it within a short approved window, such as 24 hours, and isolate its access. These durations must be negotiated and implemented; the lab's ephemeral storage does not enforce them.

Protect local files with user-only permissions, use device encryption, and avoid cloud-synced directories. Disable diagnostic logging that dumps bodies. Do not mount the home directory or source checkout into the observability backend.

Track copies in queues, caches, indexes, replicas, backups and exported reports. Stopping capture is different from deleting stored data. Provide exact-scope purge and document backup deletion limits honestly.

## Content-mode consent

Before enabling content, state the session scope, fields, destination, region, readers, retention and deletion process. Make activation visible and time-limited. Do not silently inherit content mode for new repositories or new app sessions.

Content opt-in should not grant central export automatically. A user can approve local diagnosis without consenting to a vendor or organization-wide audience.

## Access and anti-surveillance rules

Local detailed views belong to the participant. Shared dashboards should use cohorts with a minimum group size and coarse task types; define the threshold with privacy review. Access should follow role and purpose, with audit logs for central systems.

Do not build individual rankings, infer working hours, or use token totals as performance-review evidence. Collect only what supports a named improvement question. Tell participants exactly how feedback and outcome labels will be used.

## Safe fixtures and assistant analysis

Use synthetic fixtures for testing content rendering, redaction and exporter compatibility. A real failure example must be explicitly reviewed before sharing.

Treat captured prompts/tool output as hostile data when processed by an insight agent. Prevent command execution, tool invocation or secret access driven by that text. Escape UI content, block remote resource loading, and require human approval for any proposed configuration change.

## If sensitive data is captured

Stop the affected pipeline, identify destinations/copies, notify the responsible organizational team, purge according to policy, rotate any exposed credentials, repair the boundary and test with synthetic regression fixtures before restarting. Do not paste the incident payload into a public issue or docs change.

**Next:** [Scaling](scaling.md) shows how to preserve these boundaries at enterprise size.
