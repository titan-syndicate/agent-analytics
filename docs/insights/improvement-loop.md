# From numbers to an engineering improvement loop

**The loop is: identify repeated friction, propose one change, evaluate it on comparable tasks, roll it out narrowly, and verify that quality did not regress.** Dashboards are the entry point; versioned tools and evaluations are the durable output.

## The operating model

```text
Observe
  -> label outcomes and capture gaps
  -> review representative sessions
  -> write a falsifiable hypothesis
  -> change one versioned capability
  -> evaluate baseline vs treatment
  -> approve limited rollout
  -> monitor real use and counterexamples
  -> keep, revise, or roll back
```

The artifact we want is a better skill, deterministic tool, instruction bundle or workflow, with evidence for where it helps. A weekly dashboard screenshot is not an improvement artifact.

## A worked example

**Observation:** test-backed bug fixes frequently spend several tool calls discovering how to run tests.

**Hypothesis:** a repository-specific test skill with an environment preflight will reduce setup failures and interaction latency without reducing accepted fixes.

**Change:** version the skill from `baseline` to `test-preflight-v1`; select the package manager from repository metadata, verify prerequisites, and run the smallest correct test target. Do not simultaneously change model routing and global instructions.

**Evaluation:** use a small set of non-sensitive bug-fix fixtures with clear expected tests. Run baseline/treatment in clean worktrees with controlled permissions, comparable context, and recorded runtime/model configurations. Alternate/randomize order when practical. Include failures and retries, not only successful runs.

**Proposed keep criteria:** fewer setup failures and lower median/p90 interaction latency; no observed reduction in accepted results; no material increase in human rework. Predeclare what “material” means for the cohort. A 15% latency target might be a useful pilot hypothesis, not proof of an industry benchmark.

**Counterexample:** a repository with intentionally multiple test runners may need discovery. The skill should recognize that case rather than forcing the wrong command.

**Rollout:** offer it to a small opt-in cohort; compare real sessions; keep a pinned rollback version. If the result is inconclusive, collect more evidence instead of promoting it because the average token count looks good.

## The recurring review meeting

A 30-minute weekly review is enough for the first cohort:

| Time | Activity | Output |
| --- | --- | --- |
| 5 minutes | Check capture coverage and privacy status | Whether the data is fit for decisions |
| 10 minutes | Review a typical case, an outlier and a counterexample | A friction pattern with concrete evidence |
| 10 minutes | Choose one intervention and evaluation plan | Owner, bundle version, task class and criteria |
| 5 minutes | Decide previous experiment's outcome | Keep, revise, rollback or inconclusive |

Participants should be able to challenge the interpretation. “This expensive session saved a day of manual debugging” is context that a token chart lacks.

## A useful experiment record

Keep records in a private issue tracker or future experiment store, not a public telemetry repository:

```yaml
experiment_id: test-preflight-v1
task_class: test_backed_bugfix
hypothesis: reduce_environment_discovery_failures
baseline_bundle: baseline
treatment_bundle: test-preflight-v1
primary_outcome: accepted_result
efficiency_measures:
  - interaction_latency
  - input_output_tokens
  - root_ai_units
guardrails:
  - no_increase_in_human_rework
  - no_new_policy_failures
decision: pending
```

Also record sample size, task fixture versions, runtime/model differences, missing data, confidence and counterexamples. Keep links to private evidence, not copied context bodies.

## Where agents can help

| Maturity | Safe agent/tool role | Human control |
| --- | --- | --- |
| Manual | Explain a selected sanitized session, with span citations | Person chooses examples and interprets outcomes |
| Assisted diagnosis | Produce a weekly friction digest from structured summaries | Person validates patterns and rejects spurious claims |
| Assisted intervention | Draft a skill/tool change and evaluation cases | Maintainer reviews code, permissions and scope |
| Evaluated recommendation | Compare pinned configurations and summarize evidence | Owner approves rollout/rollback |
| Bounded automation | Open a change proposal for a known class of regression | No automatic global mutation or production remediation |

An insight assistant should use read-only queries, bounded data retrieval and no access to raw content unless specifically granted. Treat captured prompts/tool output as untrusted input, not instructions. Recommendations need evidence, uncertainty and a proposed disconfirming test.

## Turn local learning into shared capabilities

When a pattern recurs, fix the environment or tool before telling every engineer to prompt differently. Examples include a stable test-running integration, searchable repository map, narrow build tool, reliable MCP auth flow, reusable task-state summary, and policy-aware dependency setup.

Package successful interventions with:

* A stated task class and limitations.
* A pinned version, owner and rollback path.
* Evaluation fixtures and regression checks.
* Usage instructions and minimum permissions.
* A concise evidence record, including negative cases.

The shared marketplace or internal distribution channel should promote proven capabilities, not unreviewed prompt snippets. Adoption remains voluntary during the pilot.

## Culture: coaching and paved roads, not surveillance

Publish aggregate lessons such as “our test integration caused avoidable retries” and “this navigation skill helps investigations in these repositories.” Do not publish “engineer X uses too many tokens.”

Let participants inspect their own data, correct task labels, opt out and share only selected examples. Budget discussions should be about task value and constraints, not personal blame. Reward finding an integration problem or a failed hypothesis, not maximizing AI activity.

A high-consistency culture values repeatable verification, explicit uncertainty and improving shared tools. It does not require everyone to use the same model or style for every task.

## Longer-term maturity

**First month:** manual review, simple labels, one controlled change.

**Next quarter:** reusable evaluation suites, versioned tooling bundles, assisted weekly diagnosis, opt-in sanitized summaries.

**At organization scale:** central aggregate observability, budgets by approved task/cohort, regression detection, governed distribution and continuous evaluation. Keep individual detailed context private unless an explicit exception applies.

The long-term loop should connect operational telemetry, task evaluations, developer feedback and team delivery outcomes. None of those replaces the others.

**Next:** [Privacy and trust](../enterprise/privacy.md) sets the rules for sustaining that culture.
