#!/usr/bin/env python3
"""Create random local lab credentials without placing secrets in git."""

import base64
import json
import os
from pathlib import Path
import secrets
import subprocess


CONTEXT = "docker-desktop"
NAMESPACE = "agent-analytics-lab"
SECRET = "agent-viewer-credentials"
ROOT = Path(__file__).resolve().parents[1]


def credentials():
    values = {key: secrets.token_hex(32) for key in (
        "POSTGRES_PASSWORD", "CLICKHOUSE_PASSWORD", "REDIS_AUTH",
        "MINIO_ROOT_PASSWORD", "SALT", "ENCRYPTION_KEY", "NEXTAUTH_SECRET",
        "LANGFUSE_INIT_USER_PASSWORD",
    )}
    values.update({
        "MINIO_ROOT_USER": "agentlab",
        "LANGFUSE_INIT_PROJECT_PUBLIC_KEY": "pk-lf-" + secrets.token_hex(16),
        "LANGFUSE_INIT_PROJECT_SECRET_KEY": "sk-lf-" + secrets.token_hex(32),
        "LANGFUSE_INIT_USER_EMAIL": "local@example.invalid",
    })
    values["DATABASE_URL"] = (
        "postgresql://postgres:" + values["POSTGRES_PASSWORD"] + "@localhost:5432/postgres"
    )
    values["LANGFUSE_AUTH"] = base64.b64encode((
        values["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"] + ":"
        + values["LANGFUSE_INIT_PROJECT_SECRET_KEY"]
    ).encode()).decode()
    return values


def main():
    context = subprocess.check_output(["kubectl", "config", "current-context"], text=True).strip()
    if context != CONTEXT:
        raise RuntimeError("Select docker-desktop yourself; no context was changed")
    kubectl = ["kubectl", "--context", CONTEXT, "-n", NAMESPACE]
    # Create only the dedicated namespace when absent; never reset a cluster.
    namespace = subprocess.check_output([
        "kubectl", "--context", CONTEXT, "get", "namespace", NAMESPACE,
        "--ignore-not-found", "-o", "name",
    ], text=True)
    if not namespace.strip():
        subprocess.run(["kubectl", "--context", CONTEXT, "create", "namespace", NAMESPACE], check=True)
    existing = subprocess.check_output(
        kubectl + ["get", "secret", SECRET, "--ignore-not-found", "-o", "json"], text=True
    )
    if existing.strip():
        values = {
            key: base64.b64decode(value).decode()
            for key, value in json.loads(existing)["data"].items()
        }
    else:
        values = credentials()
        manifest = {
            "apiVersion": "v1", "kind": "Secret",
            "metadata": {"name": SECRET, "namespace": NAMESPACE,
                         "labels": {"app.kubernetes.io/part-of": NAMESPACE}},
            "type": "Opaque", "stringData": values,
        }
        subprocess.run(kubectl + ["create", "-f", "-"], input=json.dumps(manifest),
                       text=True, check=True, stdout=subprocess.DEVNULL)
    directory = ROOT / ".local-lab"
    directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    path = directory / "credentials.json"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as output:
        json.dump(values, output, indent=2)
        output.write("\n")
    print("Viewer credentials ready in .local-lab/credentials.json (private; do not share).")


if __name__ == "__main__":
    main()
