# From a user request to model calls

Start with this picture: **Copilot sends input to a selected model, and the model produces output.** The input can include much more than the sentence you typed. Some input may be served from a provider's cache.

That is a useful model for **one model call**. Copilot's agent wraps a process around it: gather context, call the model, run a tool, call the model again, and sometimes delegate to other agents. Understanding both layers is how we connect usage to something we can improve.

Read this first, then [try the six-scenario demo](../insights/demo.md). The demo deliberately leaves out message text, cache usage and streaming measurements; it teaches the shape of the work, not every part of real inference.

## Let's agree on the names

| Name | What we mean here | What you will see |
| --- | --- | --- |
| User request | The task you ask Copilot to do | Not necessarily its own exported record |
| Model call | One request to a model, with input, output and a model choice | OTel `chat`; Phoenix `LLM`; Langfuse `GENERATION` |
| Agent invocation | One agent working on a request or delegated task; it may make several model calls | OTel `invoke_agent`; Phoenix/Langfuse `AGENT` |
| Tool call | The agent runs a command or calls an integration | OTel `execute_tool`; Phoenix/Langfuse `TOOL` |
| Trace | A connected record of operations, with parent/child relationships | The tree and timeline you open in a viewer |
| Span | One timed operation inside that trace | One selectable row: agent, model call or tool call |
| Session / conversation | A longer exchange that may contain several requests and traces | Grouping by conversation ID, when the runtime exports it |
| Prompt | An ambiguous everyday word: your typed request, or the model's assembled input | Say **user request** or **model input** when the distinction matters |

The CLI also uses “turn” for model round-trips in an invocation. Do not assume a turn count is a count of user messages.

## One request can need several model calls

Imagine asking, “Fix this test.”

```text
Agent invocation: work on the test
    Model call 1: receive instructions + user request + available context
                  produce a request to run a tool
    Tool call: run the test
               return the failure
    Model call 2: receive updated context, including relevant tool output
                  produce a fix or the next action
```

This is an explanation of a common loop, not a promise that every trace has exactly this nesting or sequence. The synthetic baseline has two model calls and a tool span, but its timing is illustrative, not a faithful replay of that loop.

Tool use is not a separate kind of model pricing. The model generates a tool request as part of its response; the tool runs outside inference; useful tool results can then become input to a later model call. The tool can also have its own infrastructure cost, which token counts do not cover.

Delegation adds another loop. A coordinator can give three workers separate tasks. Each worker may call models and tools. That is **one user request, several agent invocations, and potentially many model calls**. Follow the tree; do not count every worker as another person asking a question.

## Input, output, model and cache

| Part of a model call | What it tells us | What it does not tell us |
| --- | --- | --- |
| Input tokens | How much input the provider reports processing for that call | Which components supplied those tokens, or how useful they were |
| Output tokens | How much output the provider reports generating | Whether it was a useful answer; some providers include reasoning usage |
| Requested / resolved model | What was requested and what handled the call, where exported | Why Auto chose it, or what a different model would have achieved |
| Cache-read input tokens | How much input was reported as read from the provider's cache | That the input is unnecessary, or what it cost on our Copilot plan |
| Cache-creation input tokens | Input reported as being written into a cache | A count of new user information or a universal cache accounting rule |

**Cached versus uncached is not the same as old versus new information.** Repeated text can miss a cache. Previously known information can be uncached. A cache hit does not tell us whether the text came from a skill, a file or a tool.

Also separate **input size per call** from **input consumption across calls**. Our baseline sends 4,000 tokens in one call and 6,000 in another. Its 10,000-token total is not a 10,000-token context window, and it is not 10,000 unique tokens of information. History may be sent more than once; compaction can replace it with a summary.

For usage analysis, add the unique model-call spans, not agent totals plus model-call totals. Keep tokens, Copilot usage units, invoice dollars and human time separate.

## Can our lab actually see cached input?

**Yes, when the CLI/provider exports it. Not in every call, and not in this synthetic demo.** On October 5, CLI 1.0.91 data stored in our local Phoenix project included a call with 6,255 input tokens and 6,131 cache-read input tokens. That confirms the path can preserve the field; it is not a benchmark or a guarantee for every model.

| Viewer | How to inspect a real call |
| --- | --- |
| Grafana / Tempo | Open a `chat` span's attributes. Look for `gen_ai.usage.input_tokens`, `gen_ai.usage.cache_read.input_tokens` and `gen_ai.usage.cache_creation.input_tokens` |
| Phoenix | Select an `LLM` row, then **Attributes**. Inclusive input is mapped to `llm.token_count.prompt`; the original `gen_ai.usage.*` cache fields are retained. Our Collector does not add a dedicated OpenInference cache mapping |
| Langfuse | Select a `GENERATION`. Its usage details can split input into `input`, `input_cached_tokens` and `input_cache_creation`. Compare the full breakdown, not just the uncached input label |

Langfuse can also split output into output and reasoning categories. Our read-back checks recombine its input/cache and output/reasoning categories to compare with the source counts. Phoenix's prompt/completion fields are inclusive source counts, not a new estimate.

**Missing is unknown, not zero.** The six demo cases have no cache fields, so they cannot teach cache savings or compare cached and uncached spend. The [telemetry reference](telemetry.md) lists the native fields and aggregation cautions.

## What goes into the input?

These are possible contributors, not separate billable products. Copilot assembles the actual input; discovery, loading, retrieval and compaction affect what reaches each call.

| Contributor | How it can enter the input | What our metadata can tell us today |
| --- | --- | --- |
| User request and conversation history | Current request, previous exchanges or summaries | Call sizes; compaction/truncation signals where exported, not a history-token budget |
| System and repository instructions | Runtime rules, custom instructions and repository guidance | No reliable per-source token breakdown with content off |
| Skill descriptions and loaded skill content | Discovery information and instructions loaded when relevant | Skill-invocation events where emitted; an invocation is not a measurement of skill tokens |
| Tool definitions | Names, descriptions and argument schemas for available tools | Tool execution spans show use, not the token cost of every available definition |
| Files, search and retrieved documents | Content read directly or returned by retrieval tools | Tool identity, timing and status; not exact included text or tokens |
| Tool results | Test failures, logs, command output, API responses | Tool spans can explain the sequence; they do not prove how much output was retained for the next call |
| Delegated work | Instructions/context given to workers and results returned | Agent hierarchy where exported; no automatic shared-versus-duplicated-context measurement |

A tool returning 20,000 characters does **not** prove the next model received all of them. The runtime can filter, summarize or truncate them. Character counts are not model token counts either.

This is why a growing-input chart is the start of an investigation, not the answer “our skills are too big.”

## Can we characterize input without reading thousands of prompts?

That is the right next question. **We do not currently have a component-level input budget.** OTel is a way to transport measurements; Phoenix and Langfuse can display fields they receive, but they cannot reconstruct missing provenance.

Work in three layers:

1. **Use the metadata we have.** Group comparable tasks by model, per-call input/output, cache fields when present, number of calls, tool failures and agent fan-out. Use skill/compaction events as clues. This finds cases worth reviewing without collecting message text.
2. **Inspect a few approved fixtures.** With explicit approval, use sanitized example inputs to check the hypothesis. The CLI supports optional message content, instructions, tool definitions and tool arguments/results, but our launcher keeps capture off. Content export can be incomplete and does not reliably label every token by its source. Do not enable broad capture just to fill empty panels.
3. **Add input-budget instrumentation if we need attribution.** This is a proposal, not an installed feature. A runtime/context-assembly hook could label components as instruction, skill, history, retrieval, tool schema or tool result; record safe source/version identifiers, included sizes and truncation decisions; and aggregate by task class. We would need runtime support, privacy review and a tested schema first.

For that third layer, measure the **actual assembled input**, not just the files or tool output available to the agent. Record tokenizer/model/version and distinguish approximate component counts from provider-reported totals. Component boundaries and tokenization can make naive sums disagree. Cache reporting may not identify which component was cached; keep cache accounting separate unless the provider supports that attribution.

A useful future view would answer, “In this task class, which component tends to grow between calls?” It should summarize distributions and outliers, not make someone scroll through hundreds of private prompts. It could be a dashboard over additional span attributes, rather than a fourth viewer. No such input-optimization view is implemented here yet.

## Where does streaming fit?

Streaming changes **how output arrives**, not the basic input/model/output picture. One model call can send many chunks; those chunks are not separate prompts or model calls, and a chunk is not necessarily one token.

The CLI documents `gen_ai.response.time_to_first_chunk` and streaming latency metrics. When exported, use these to separate “how long before anything appears?” from “how long until the call finishes?” A span's total duration alone cannot make that distinction, and the first chunk may not be visible answer text.

Reported output usage is still the call's usage. Partial, aborted or missing exports need special handling; do not infer their total from how many chunks you saw. Our synthetic demo has durations but no chunk timing, so it cannot explain streaming speed.

## Use this picture in a demo

Say: **“First we look at input, output and model choice for each call. Then we look at the agent's process: how many calls, which tools, which failures, and which workers. Cache tells us how input was served; it does not tell us where that input came from.”**

Then [choose a scenario](../insights/demo.md). The tool walkthroughs translate this picture into clicks: [Grafana](../insights/demo-grafana.md), [Phoenix](../insights/demo-phoenix.md) and [Langfuse](../insights/demo-langfuse.md).

Sources: [GitHub CLI monitoring reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#opentelemetry-monitoring), local CLI 1.0.91 `copilot help monitoring`, [our telemetry reader](telemetry.md) and the checked-in Collector mapping. Desktop export remains a separate, unverified path.
