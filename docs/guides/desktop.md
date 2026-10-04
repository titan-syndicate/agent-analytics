# Copilot desktop: a compatibility experiment, not a promise

**Do not assume that configuring your shell configures the GitHub Copilot app.** The current [enterprise managed settings matrix](https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings#supported-keys) explicitly marks the app's `telemetry` key as **not supported**, while the CLI supports it.

That does not prove every app-launched runtime is incapable of exporting. It does mean a supported app-wide switch should not be invented or implied. We have not executed an app-specific capture test in this project.

!!! tip "You do not have to wait for live export to study app sessions"
    GitHub documents local app/CLI session records under `~/.copilot/session-state/` and a SQLite subset in `session-store.db`. [Analyze local session files](local-session-data.md) explains the retrospective fallback, built-in `/chronicle` insights, missing ephemeral metrics, and a proposed read-only importer.

## Separate the surfaces

| Surface | Current evidence | Pilot treatment |
| --- | --- | --- |
| Terminal Copilot CLI | Documented environment-variable export | First supported capture path |
| Copilot SDK application | Documented `TelemetryConfig` | Supported when we own the SDK host |
| Copilot desktop local project session | No verified app-wide telemetry configuration in this reader | Test actual child runtime environment and emitted signals |
| App chat without a project | May use a different execution path | Test separately; do not infer coverage from a project session |
| App session on a remote host / container | Runtime and collector are not necessarily on the laptop | Configure/test where the runtime executes |
| Cloud agent session | Not a local CLI process we control | Out of scope for the local-only pilot |
| VS Code Copilot | Separate documented settings | Do not reuse VS Code configuration keys in the desktop app |

The current [app customization guide](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app) documents skill/plugin integration, not automatic OTel support. A startup skill can start infrastructure, but cannot retroactively change its parent's telemetry initialization.

## A controlled local experiment

The [checked-in Tilt lab](local-lab.md) now supplies the backend and synthetic read-back check. The remaining app-specific setup is a full quit, launch with the verified environment, and a new session; this is not a no-restart change. Quitting the app may interrupt other active sessions, so schedule that step deliberately. The [CLI experiment](../experiments/cli-local-otel.md) does not validate desktop inheritance.

1. Record the desktop version, session surface, execution host, and bundled CLI/runtime version if available. Use a new safe project session, not the session carrying your production work.
2. Bring up the [synthetic-tested local backend](local-lab.md).
3. Fully quit the desktop app through its normal quit flow. Do not terminate unrelated Copilot processes. Existing app instances may reuse their previous environment.
4. Launch the app's actual executable from a terminal containing the [local CLI environment](copilot-cli.md). Prefer a documented per-host environment setting if a future app version adds one.
5. Start a fresh session and run a harmless task. Inspect both the runtime process configuration and the collector/backend.
6. Verify conversation/model/tool spans, content absence, and repeatability across app restart. A successful terminal CLI task is not evidence for desktop capture.

### macOS launch hypothesis

For an application whose installed executable really has this path, a direct launch could look like:

```sh
# After setting the local telemetry environment and fully quitting the app:
"/Applications/GitHub Copilot.app/Contents/MacOS/GitHub Copilot"
```

**This path is illustrative and must be checked on your installation.** Do not substitute an unverified binary path, edit app bundles, globally change `launchctl` environment, or assume `open -a` forwards shell variables. App process managers can discard or replace the environment before starting the runtime.

On Windows/Linux, use the actual installed executable from an explicitly configured shell and repeat the same proof. The app may not support that launch route; report the result rather than working around its internals.

## What counts as a pass?

| Gate | Evidence required |
| --- | --- |
| Environment | Endpoint/protocol/content-off settings reach the process that exports telemetry |
| Capture | A new app task appears, not just a separate terminal CLI task |
| Identity | The session can be associated with the app and execution host without leaking personal paths |
| Privacy | No content fields or unexpected identifying/error payloads in exported records |
| Lifecycle | Restart, session creation and normal shutdown preserve the expected behavior |
| Coverage | Supported/unsupported project, chat and remote surfaces are explicitly listed |

Record outcomes as **supported by documentation**, **experimentally working on version X**, **not working**, or **not tested**. “No spans observed” should include the checks that ruled out a broken collector.

## If it fails

Keep the CLI pilot usable. Ask the app maintainers for a documented per-execution-host OTel setting or environment propagation mechanism; attach a sanitized reproduction, not process dumps or session data.

Do not proxy or decrypt model traffic, reverse-engineer undocumented app-internal databases, or automatically replace the bundled CLI. These approaches create security, correctness and maintenance problems and still do not guarantee session attribution. Read-only analysis of the **documented** local session store is a separate, useful [fallback](local-session-data.md); it is not a live telemetry switch.

The Copilot SDK offers documented telemetry configuration **when we own the host application**. It is not a switch for a closed desktop application's SDK configuration.

## Implication for the proposed launcher

The installer must report surface-specific coverage honestly:

```text
CLI: configured and verified
Desktop local project sessions: compatibility experiment required
Desktop chat: not verified
Remote/cloud: separate host configuration required
```

A button saying “capture enabled” is misleading if it only started a collector. See [capture and distribution](../proposals/capture.md) for the capability contract.
