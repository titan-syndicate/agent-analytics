# Read the demo in Langfuse

**Langfuse calls the operations inside a trace “observations.”** For our lab, an agent is an `AGENT`, a model call is a `GENERATION`, and a tool call is a `TOOL`. These are the same operations you see in Phoenix, with different labels.

Start with the [model-call guide](../foundations/model-calls.md) if input, cached input or the difference between a request and an agent invocation is still unclear.

## Get to the trace

1. Open **[Langfuse](http://127.0.0.1:3001)**. Sign in as `local@example.invalid` with `LANGFUSE_INIT_USER_PASSWORD` from your private `.local-lab/credentials.json`. Do not paste the credentials into chat or the public docs.
2. Choose organization **Local lab** and project **Copilot comparison**. Open **Traces**.
3. Set the time range to include your run and clear unrelated filters. Open the trace named for the scenario, such as **DEMO A scoped fix**. Prefer the direct scenario link in `.local-lab/demo-links.md` if there are several runs.
4. Find the observation tree/timeline in the trace detail view. Select a named model-call or tool row to see its details. Show a parent's children with its disclosure control if they are hidden.
5. On a model call, inspect **model**, **usage** and **metadata**. If usage is collapsed, open its detail/breakdown control. Compare the selected generation's values rather than mixing them with trace rollups.

The links below open the October 5 data on this local lab. They are not public telemetry. For a fresh installation or reset, [generate the demo](demo.md#start-the-demo) and use your new links. UI placement can change; our lab pins Langfuse **4.50.0**.

## Baseline

**[Open the seeded baseline trace](http://127.0.0.1:3001/project/copilot/traces/6c37acef04e65a7d54160e8f67de2a71)**, or choose **DEMO A scoped fix** in Traces.

The root agent groups two generations and one tool. Select **DEMO model call 1**: model **demo-small**, input **4,000**, output **200**. Then select **DEMO model call 2**: input **6,000**, output **300**.

Select **DEMO test command 1**. Its metadata includes `agent_analytics.demo.tool_result=passed`. Root metadata includes the invented `accepted (fixture)` outcome. This is **not** a Langfuse evaluation score or proof that a fix passed review.

**Say:** “The trace puts usage next to the process and an outcome label. We still need to define what acceptance means on a real task.”

Empty Input/Output content is expected. These generations have no cache fields or captured messages.

[Back to the scenario](demo.md#1-start-with-a-scoped-fix) · [Grafana](demo-grafana.md#baseline) · [Phoenix](demo-phoenix.md#baseline)

## Context

**[Open the seeded context trace](http://127.0.0.1:3001/project/copilot/traces/e8367ef54039121cfa20dd1bee4d60d5)**. The root is **DEMO Repeated broad context**.

Select model calls **1** through **4**. Their input values grow **8,000 -> 24,000 -> 48,000 -> 80,000**; output is **250, 250, 300, 300**. The total is 160,000 input tokens across calls, not one prompt.

**Say:** “We can see input growing. We cannot yet attribute it to history, skills or tool results.”

On real captures, inspect the usage breakdown: `input` can be the uncached portion, with `input_cached_tokens` and `input_cache_creation` reported separately. Our verifier adds those categories to compare with the source's inclusive input. The demo omits cache fields; an absent category is not evidence of zero cache use in real Copilot tasks.

Use [cache versus input provenance](../foundations/model-calls.md#can-our-lab-actually-see-cached-input) to explain why “uncached” does not mean “new information.”

[Back to the scenario](demo.md#2-repeated-broad-context) · [Grafana](demo-grafana.md#context) · [Phoenix](demo-phoenix.md#context)

## Output

**[Open the seeded output trace](http://127.0.0.1:3001/project/copilot/traces/e4008f6921c86a3d901b3b25d558bdbd)**. The root is **DEMO Verbose output**.

Select its two generations. Output is **3,000 / 6,000**, while input remains **4,000 / 6,000**. Compare with baseline's **200 / 300** output.

**Say:** “The extra usage is output, not extra agents or more calls. Now we need to ask whether the result required it.”

Some real provider responses split reasoning usage into `output_reasoning_tokens`. Compare output plus reasoning when reconciling with an inclusive source count. The synthetic case does not include reasoning or text, so it cannot tell us what those 9,000 tokens contained.

[Back to the scenario](demo.md#3-verbose-output) · [Grafana](demo-grafana.md#output) · [Phoenix](demo-phoenix.md#output)

## Retry

**[Open the seeded retry trace](http://127.0.0.1:3001/project/copilot/traces/ba8fa99a0f5d32c837b94c6aa04fe53f)**. The root is **DEMO Broken test harness retries**.

Select tool observations **DEMO test command 1** through **4**. Look for their error indication and metadata value **runner unavailable**. Command **5** says **passed**. Inspect the five generation observations as well: input grows **6,000, 9,000, 14,000, 20,000, 26,000**.

**Say:** “We have a specific environment failure to investigate, not just a high-token task.”

The root's `unknown (fixture)` outcome matters: the final tool success does not establish task success. This is a hypothesis about a retry loop, not proof that every repeated call was waste.

[Back to the scenario](demo.md#4-broken-test-harness-retries) · [Grafana](demo-grafana.md#retry) · [Phoenix](demo-phoenix.md#retry)

## Fanout

**[Open the seeded fan-out trace](http://127.0.0.1:3001/project/copilot/traces/a86558dd71762af330493881669df7e8)**. The root is **DEMO One prompt, several agents**.

Show the children of **DEMO worker 1**, **2** and **3**. Each worker has one generation with **10,000 input** tokens. The root also has model calls **1** and **5**, with **6,000** and **18,000** input tokens. That is four agents and five generations, not five user requests.

**Say:** “We can follow delegation. To decide whether it helped, we would link each worker to a required deliverable and check for duplicate effort.”

The root duration is **22 seconds**, and workers overlap. Do not add their durations as elapsed time. This fixture has no worker output text or evaluation scores. Start in the trace tree; session rollups are not needed for this case.

[Back to the scenario](demo.md#5-one-prompt-several-agents) · [Grafana](demo-grafana.md#fanout) · [Phoenix](demo-phoenix.md#fanout)

## Routing

**[Open the seeded routing trace](http://127.0.0.1:3001/project/copilot/traces/9b09adf01403f737a106184ec1605903)**. The root is **DEMO Larger resolved model**.

Select the two generations and read the **model** field: **demo-large**. Usage matches baseline's **4,000 / 6,000 input** and **200 / 300 output**. In metadata, requested and response model fields also match. There is no Auto rationale in this fixture.

**Say:** “Model identity is part of a comparison, not a verdict. We need accepted-task results from both configurations and actual Copilot billing terms.”

Ignore generic viewer price estimates for this exercise. No real rate card is attached to these invented models, and provider token prices are not automatically Copilot invoice prices.

[Back to the scenario](demo.md#6-a-larger-resolved-model) · [Grafana](demo-grafana.md#routing) · [Phoenix](demo-phoenix.md#routing)

## What sessions and scores would add

A **session** groups traces by the mapped conversation ID when it exists. It is useful for longer conversations, but the mapping does not invent missing IDs or guarantee complete worker/session coverage.

Langfuse supports scores and evaluations; our generator creates only metadata labels. A later pilot could attach approved test/review outcomes and compare versions of a skill or harness. That work has not been implemented by opening these traces.

No trace? Check the project, time range and fresh local links. If everything disappeared, the disposable storage may have been replaced. See [missing-data diagnosis](../guides/generate-and-find-data.md#diagnose-missing-data-in-order).
