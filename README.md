# Agent Analytics

A reader-first, local-first field guide to observing GitHub Copilot sessions and
turning evidence into better agent tooling, consistent outcomes, and efficient AI spend.

**Read the site:** <https://titan-syndicate.github.io/agent-analytics/>

Start with [recommendations for high-volume users](docs/start/recommendations.md),
then the [30-day pilot](docs/start/pilot.md). The site includes Copilot CLI and
Honeycomb setup, an illustrative Tilt/Kubernetes lab, a desktop compatibility
experiment, [local session-file/SQLite analysis](docs/guides/local-session-data.md),
separate capture/viewer proposals, OpenSearch tradeoffs, and an
enterprise improvement loop.

This repository currently contains documentation, **not an implemented telemetry
product**. Local infrastructure snippets are lab recipes; the proposed launcher,
skill, policy gateway, and agent-specific viewer are not shipped. No real session
content or credentials belong here.

## Preview and build

Use Python 3.10 or newer (CI uses 3.12):

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-docs.txt
.venv/bin/python -m mkdocs serve
```

For a production build with link and navigation validation:

```sh
.venv/bin/python -m mkdocs build --strict
```

[Publish documentation](.github/workflows/docs.yml) builds on relevant changes
to `main` and supports manual dispatch. Pull requests build without deploying.
Pages uses GitHub Actions as its publishing source; see
[site maintenance](docs/reference/site.md).
