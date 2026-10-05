#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
need kubectl; need openssl
[ "$(kubectl config current-context)" = docker-desktop ] || fail "Select docker-desktop yourself"
kubectl=(kubectl --context docker-desktop -n "$NAMESPACE")
if [ -z "$(kubectl --context docker-desktop get namespace "$NAMESPACE" --ignore-not-found -o name)" ]; then
  kubectl --context docker-desktop create namespace "$NAMESPACE"
  kubectl --context docker-desktop label namespace "$NAMESPACE" "app.kubernetes.io/part-of=$NAMESPACE"
fi
[ "$(kubectl --context docker-desktop get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" = "$NAMESPACE" ] ||
  fail "Namespace is not labeled as this lab; inspect ownership before using it"
private_dir
temporary=$(mktemp "$ROOT/.local-lab/credentials.XXXXXX")
trap 'rm -f "$temporary" "$temporary.next"' EXIT
existing=$("${kubectl[@]}" get secret agent-viewer-credentials --ignore-not-found -o json)
if [ -n "$existing" ]; then
  printf '%s' "$existing" | jq '.data | map_values(@base64d)' > "$temporary"
else
  printf '{}\n' > "$temporary"
  for key in POSTGRES_PASSWORD CLICKHOUSE_PASSWORD REDIS_AUTH MINIO_ROOT_PASSWORD SALT \
      ENCRYPTION_KEY NEXTAUTH_SECRET LANGFUSE_INIT_USER_PASSWORD; do
    value=$(openssl rand -hex 32)
    data=$(jq --arg key "$key" --arg value "$value" '. + {($key): $value}' "$temporary")
    printf '%s\n' "$data" > "$temporary"
  done
  jq --arg pk "pk-lf-$(openssl rand -hex 16)" --arg sk "sk-lf-$(openssl rand -hex 32)" '
    . + {MINIO_ROOT_USER:"agentlab", LANGFUSE_INIT_USER_EMAIL:"local@example.invalid",
         LANGFUSE_INIT_PROJECT_PUBLIC_KEY:$pk, LANGFUSE_INIT_PROJECT_SECRET_KEY:$sk} |
    .DATABASE_URL = ("postgresql://postgres:" + .POSTGRES_PASSWORD + "@localhost:5432/postgres") |
    .LANGFUSE_AUTH = ((.LANGFUSE_INIT_PROJECT_PUBLIC_KEY + ":" + .LANGFUSE_INIT_PROJECT_SECRET_KEY) | @base64)
  ' "$temporary" > "$temporary.next"
  mv "$temporary.next" "$temporary"
  jq --arg namespace "$NAMESPACE" '{
    apiVersion:"v1", kind:"Secret", type:"Opaque",
    metadata:{name:"agent-viewer-credentials",namespace:$namespace,
              labels:{"app.kubernetes.io/part-of":$namespace}},
    stringData:.
  }' "$temporary" | "${kubectl[@]}" create -f - >/dev/null
fi
chmod 600 "$temporary"
mv "$temporary" "$ROOT/.local-lab/credentials.json"
printf 'Credentials ready in .local-lab/credentials.json (private, gitignored).\n'
