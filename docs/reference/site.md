# Maintaining and publishing this site

This site uses MkDocs with Material, explicit navigation and search. All published content lives under `docs/`; `mkdocs.yml` defines its reading order. No telemetry collector or live session dashboard is part of GitHub Pages.

The theme uses neutral navigation, teal links, and restrained rainbow accents in `docs/stylesheets/rainbow.css`. Light and dark modes keep normal reading text solid; forced-color mode restores system colors.

## Preview locally

Use Python 3.10+; CI uses 3.12:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-docs.txt
.venv/bin/python -m mkdocs serve
```

Open the development server address printed by MkDocs. Dependencies are pinned at the top level in `requirements-docs.txt`; transitive dependencies are not fully locked. Update them deliberately and rebuild before publishing.

## Build checks

```sh
.venv/bin/python -m mkdocs build --strict
```

Strict mode treats configured warnings as errors, including missing navigation pages and broken internal page/anchor references. It does not validate external websites or run the lab commands.

Add each new reader page to the navigation, use relative internal links, cite capability claims and distinguish proposed functionality from delivered functionality. Keep actual telemetry, keys and private experiment records out of this repository.

## GitHub Pages setup

The repository's Pages publishing source must be **GitHub Actions**:

1. Open repository **Settings -> Pages**.
2. Under **Build and deployment**, choose **GitHub Actions**.
3. Allow the workflow's `github-pages` environment to deploy from `main`.

The workflow uses the official Pages artifact/deployment actions. It does not create a `gh-pages` branch or require a long-lived publishing token.

## Publish from main

[Publish documentation](https://github.com/titan-syndicate/agent-analytics/actions/workflows/docs.yml) builds and deploys on relevant pushes to `main`. It also accepts manual dispatch:

```sh
gh workflow run docs.yml --ref main
gh run list --workflow docs.yml --limit 5
gh run watch RUN_ID --exit-status
```

Pull requests build strictly but do not deploy. The deploy job uses only `pages: write` and `id-token: write`; repository contents permission remains read-only. Action revisions are pinned, and builds use a fixed Python version.

The canonical published URL is:

<https://titan-syndicate.github.io/agent-analytics/>

Verify both the workflow conclusion and a real page fetch after publishing. Pages/CDN propagation can take a little time; a queued action is not publication success.

## Public content policy

This repository and site are public. Publish generic recommendations, synthetic examples and reviewed aggregate lessons only. Screenshots or examples containing session IDs, customer data, code, prompts or credentials need separate review and should normally remain private.

Do not add a telemetry ingest endpoint, analytics beacon or externally hosted session payload to this static reader.
