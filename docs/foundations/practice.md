# What should we call this practice?

**“AI-assisted engineering effectiveness” is the best umbrella for this project.** “Agent observability and evaluation” names the technical work, and “AI FinOps” names the financial discipline. These are clearer than using AIOps for the entire effort.

Terminology is still evolving. “AgentOps” is useful shorthand, but products use it inconsistently; define it rather than assuming it implies a standard capability.

## AIOps is related, but not the whole goal

AIOps conventionally means **artificial intelligence for IT operations**: applying AI to operational data for anomaly detection, alert correlation, root-cause assistance and remediation. See [IBM's AIOps overview](https://www.ibm.com/think/topics/aiops).

We are initially **observing AI systems and human-agent workflows**, not using AI to operate the IT estate. If an agent later analyzes our tool failures and proposes remediation, that portion resembles AIOps. Merely exporting Copilot spans does not.

| Concern | Useful term | What it contributes |
| --- | --- | --- |
| Trace model/tool behavior | Agent observability | Explain the execution path and operational failures |
| Judge correct, accepted results | Agent evaluation / LLMOps | Test datasets, rubrics, regression gates |
| Improve instructions, skills and integrations | AI developer enablement / platform engineering | Reusable “paved roads” and reliable tools |
| Attribute usage and decide where spend is worthwhile | AI FinOps | Unit economics, budgets and value discussions |
| Improve developer experience and delivery | AI-assisted engineering effectiveness / DevEx | Workflow friction, quality, feedback and outcomes |
| Apply AI to operational incident data | AIOps | Detection, diagnosis and bounded automation |
| Operate models and ML pipelines | MLOps | Less central when GitHub hosts the models |

## Three measurement layers

**Execution:** tokens, model calls, durations, retries, tool failures, context events. OTel is strong here.

**Task outcomes:** tests, acceptance, rework, review quality, escaped defects. These require labels or integration with engineering systems.

**Organizational value:** shorter delivery lead time, improved reliability, lower toil, better experience and justified spend. This requires longer-term evidence and context; it cannot be computed from a token dashboard alone.

Keep these layers separate. An agent that uses fewer tokens but creates more review work is not necessarily more efficient.

## Connect to existing disciplines

[FinOps](https://www.finops.org/introduction/what-is-finops/) emphasizes shared accountability and technology value, not simply cost reduction. The useful question is “what accepted outcome did this spend enable?” rather than “who spent the most?”

[DORA](https://dora.dev/guides/dora-metrics/) provides delivery outcome measures and explicitly cautions against disparate comparisons and competition. Use those at a service or team level to contextualize adoption; do not treat them as direct session telemetry or individual scores.

The [SPACE framework](https://queue.acm.org/detail.cfm?id=3454124) reinforces that developer productivity is multidimensional: satisfaction/well-being, performance, activity, communication/collaboration, and efficiency/flow. Pair telemetry with participant feedback and outcomes instead of elevating activity to value.

## Suggested internal language

Call the program **AI-assisted engineering effectiveness**. Call its technical platform **agent observability and evaluation**. Describe the improvement method as **measure -> diagnose -> evaluate -> improve -> verify**.

This gives the RE/SRE team, developer platform team, engineering leaders and finance partners a common conversation without implying that a dashboard can objectively rank people.

**Next:** [What Copilot telemetry can tell us](telemetry.md).
