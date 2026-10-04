# Analyze local Copilot session files without live OTel

**Yes: locally stored session history is a useful fallback for Copilot desktop analytics.** GitHub documents that both Copilot CLI and locally run app sessions store their complete session record under `~/.copilot/session-state/`, with a subset in `~/.copilot/session-store.db`.

This approach is **retrospective session analysis**, not native OTel instrumentation. It can help us study tool failures, repeated attempts and conversation flow now, while we work out live desktop export. Start with completed sessions and local metadata summaries; add reconstructed spans only when they answer a concrete question.

!!! info "Scope and verification"
    Storage locations and history features are documented upstream. This project has not inspected your home directory or tested a parser against your desktop sessions. The adapter described below is a proposal, not a shipped importer. Exact event fields and persistence must be verified against the installed runtime.

## What is in the local Copilot directory?

The [configuration directory reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference#session-state) documents this layout:

```text
~/.copilot/
    session-state/
        <session-id>/
            events.jsonl       # Session event log
            ...                # Plans, checkpoints and workspace artifacts
    session-store.db            # Cross-session SQLite index/subset
    ...                        # Settings, providers, permissions and other data
```

`COPILOT_HOME` can change the CLI configuration directory. Do not assume the desktop app uses a variable set only in your shell; verify its actual execution host and configuration root.

| Source | Good use | Important boundary |
| --- | --- | --- |
| `events.jsonl` for selected sessions | Ordered events, messages, tool activity and recorded metadata | Sensitive raw history; event format evolves |
| `session-store.db` | Finding sessions, indexed history, available aggregate metadata | A subset, not the full event stream; schema is not a promised analytics API |
| Checkpoints | Context snapshots when diagnosing an approved example | Snapshots overlap history; do not count each as new activity |
| Plans/artifacts | Understanding a selected task | Arbitrary content, not a reliable metrics source |
| Other files in `~/.copilot` | Not needed for this analysis | May contain configuration or credential-related data; exclude them |

The official [session-data reader](https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/session-data) distinguishes local storage, account syncing and sharing. Local files do not imply that the source session was never synced: local sessions sync by default subject to settings and enterprise policy. Remote-host data may be on that host; cloud or IDE history is not automatically covered by these paths.

## The easiest first step: built-in session insights

The [desktop session guide](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions#using-chronicle-with-app-sessions) explicitly says the app is built on CLI and can use `/chronicle` to analyze app and CLI history.

In a supported installed version, try:

```text
/chronicle standup for the last 3 days
/chronicle tips
/chronicle cost-tips
```

Ask for a bounded question such as: “For this repository's recent bug-fix sessions, identify repeated test-command failures and cite the supporting sessions. Separate observations from guesses.”

This is a useful way to discover candidate improvements before building an importer. It is not a reproducible measurement pipeline or a guaranteed monetary cost calculation. Confirm conclusions against examples and outcome labels.

!!! warning "On-disk does not mean analysis stays local"
    GitHub states that querying history or using `/chronicle` may send relevant prompts, context and responses to the AI model. Do not use it for a strict no-egress analysis requirement without approval. A local deterministic parser can avoid model calls; a hosted insight agent cannot make the same promise.

`/chronicle improve` can propose and apply instruction-file changes; treat it as an intervention requiring review and evaluation, not a read-only report. `/chronicle reindex` rebuilds the index **and can sync session data**; do not run it as a harmless prerequisite for an offline experiment.

## What can we learn from saved events?

The [SDK event reference](https://github.com/github/copilot-sdk/blob/main/docs/features/streaming-events.md) documents an envelope with event ID, timestamp, type, payload, optional subagent ID and previous-event `parentId`. It is useful evidence for adapter design, **not a guarantee that every desktop version persists every SDK event**.

| Insight | Candidate recorded evidence | Limit |
| --- | --- | --- |
| Tool reliability | `tool.execution_start` / `tool.execution_complete`, tool name, success | Verify persistence and field coverage; missing completion is unknown, not success |
| Tool elapsed time | Matching starts/completions by `toolCallId` and timestamps | Event elapsed time, not exact CPU time; includes runtime scheduling overhead |
| Repeated attempts | Tool sequence, errors and subsequent activity | Same tool name does not prove same arguments or wasted work |
| Conversation flow | User/assistant messages and turn events when stored | A conversation turn is not necessarily one model API call |
| Context churn | Recorded compaction/truncation events or snapshots, if present | Cannot infer exact context size from message length alone |
| Skill/tooling patterns | Explicit recorded invocation/version metadata, if present | Do not infer that a skill was used from an instruction file's existence |
| Token usage | Persisted usage records or index aggregates, **if present** | Coverage and grain must be established before totals |
| Quality/value | Outcome labels plus tests, review and participant feedback | Saved conversation “looks done” is not proof of accepted results |

## The biggest gap: not everything is persisted

The SDK reference marks `assistant.usage` **ephemeral**: it describes per-API-call input/output/cache tokens, model multiplier, duration and streaming timing, but ephemeral events are not saved to the session log or replayed on resume.

Therefore, an importer must **not promise** that `events.jsonl` contains per-call tokens, time-to-first-token or exact model-call duration. A particular runtime may persist other usage records or aggregates in its index; discover and document those separately. Keep absent values null and disclose coverage.

Streaming deltas and progress events may also be ephemeral. Message timestamps are not a substitute for first-token latency, and an assistant response can follow several model/tool cycles.

History is enough to investigate many workflow patterns, but not to recreate an unrecorded provider trace, hidden model reasoning, or a faithful billing ledger. Full saved conversation content is also not necessarily the exact provider input after context selection/compaction.

## A safe local pilot

1. Choose a completed, non-sensitive app session and record app/runtime versions, execution host and session ID privately.
2. Verify that its local history exists and corresponds to the task. Do not recursively ingest every file under `~/.copilot`.
3. Select only its event log, or explicitly choose the SQLite store for index-level exploration. Keep all raw input private and read-only.
4. Inspect field names and event-type counts locally; do not print or upload whole payloads for debugging.
5. Produce an allowlisted summary: tool counts, known failures, paired elapsed times, event coverage and an optional task/outcome label.
6. Compare the summary to the app's visible history by hand. Test duplicates, incomplete records and missing usage.
7. Repeat for 10-20 comparable sessions, then use the [improvement loop](../insights/improvement-loop.md) to test one tooling change.

### SQLite exploration: schema first, no assumed table names

For the default path, this command reads only the schema catalog, not prompt bodies:

```sh
sqlite3 -readonly "$HOME/.copilot/session-store.db" \
  "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') ORDER BY name;"
```

Use the actual verified path if configuration differs. Table names themselves should still stay private. Inspect only the needed table schema next, then select explicit metadata columns with a time bound and row limit; do not start with `SELECT *`, full-text export or `.dump`.

GitHub calls this database automatically managed and says it should not be edited. Do not apply migrations, change journal settings, write indexes or repair it with an analytics tool.

If a stable snapshot is needed, use SQLite's online backup API into a user-only private directory; copying only the `.db` file while SQLite uses WAL can miss committed data. A snapshot may contain all indexed history, so use one only if that broader copy is approved, sanitize before downstream use, and expire it promptly. Do not use `immutable=1` to bypass coordination on a database that is changing.

### Event-log exploration: start with completed files

Do not modify the source log. A growing JSON-lines file can end with a partially written record; distinguish that from malformed completed records. Report parse failures without logging raw lines.

For a future live tailer, commit its byte-offset cursor only after complete validated records. Detect truncation/replacement, deduplicate by session/event ID, and preserve incomplete-pair and unknown-event counts. A resumed session is not automatically a new task.

## Proposed importer architecture

```text
Selected completed session events / read-only index
    -> native local reader (explicit path allowlist)
    -> version-specific parser and privacy allowlist
    -> normalized event records with provenance and coverage
    -> local session summaries / proposed viewer
    -> optional reconstructed OTLP spans
    -> existing local Collector and backend
```

Prefer a native host reader that sends **only sanitized records** to the lab. Do not mount all of `~/.copilot`, your home directory or source tree into a container. Even a read-only mount exposes the content to that container.

Tilt can start the optional summary service/viewer and collector. It does not need to alter the running desktop app for this path. A future skill could request selected-session import and run the coverage check; it must not silently scan unrelated history.

### Reconstructing OTel-like traces honestly

For tools, pair start/completion events by session, agent identity where applicable, and `toolCallId`. Preserve timestamps; unmatched or reversed pairs remain incomplete. `parentId` in the documented event envelope points to the **previous event**, not a causal parent span. Do not turn that linked list into a fabricated call tree.

Map confirmed tool pairs to derived `execute_tool` spans; preserve conversation identity and verified subagent relationships. Do not manufacture `chat` spans or durations from every assistant message. If the source does not establish causality, show ordered events or use links rather than invented nesting.

Use deterministic synthetic IDs with a documented namespace and stable source record identity; mark every imported record, for example:

```text
agent_analytics.source = session_files
agent_analytics.reconstructed = true
agent_analytics.adapter_version = 1
```

These are proposed custom attributes. Keep original event IDs and parsing/derivation versions in private provenance, and never merge imported and native OTel usage blindly. Native OTel and imported history can describe the same work; identify overlap before aggregating.

Historical spans carry original timestamps. Search the original time range and check backend retention/old-data rejection before backfilling; do not rewrite timestamps to “now” to make them visible. Derived cumulative metrics must be replay-safe, not counters incremented again on every re-import. Session summaries are often simpler than emitting metrics for historical data.

## Privacy is different from metadata-mode OTel

Setting `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false` controls the exporter; it does **not** remove prompts/tool results already saved for session history.

The importer is reading sensitive content-bearing files even if its output is metadata-only. Allowlist output before logs, queues, storage and model access. Exclude message text, arguments/results, plans, attachments, arbitrary errors, paths and identifying metadata by default. Keep tool error categories rather than verbatim error messages.

Do not enable cloud sync, share a session, export a gist, or upload a database as part of “local analytics.” Prefer supported app/CLI controls for source-session management. Purging derived analytics is separate from deleting source/synced sessions; explain all copies and never delete the user's Copilot history automatically.

## Recommendation for our pilot

For desktop-first participants, **start with local-history analysis now**, without waiting for a live OTel switch. Use built-in insights only when their model-data boundary is acceptable; otherwise use a reviewed local parser. Continue native OTel with CLI participants for better provider-level timing and usage coverage.

Both routes should feed the same outcome/evaluation workflow, while keeping their evidence quality distinguishable. The first deliverable is a trustworthy private session summary, not a perfect reconstruction of Honeycomb's frames.

**Next:** [Capture and distribution proposal](../proposals/capture.md) and [session viewer proposal](../proposals/viewer.md).
