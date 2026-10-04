# A Tilt + Docker Kubernetes local lab

**Tilt is a good fit when Docker Desktop Kubernetes is already running.** Use one LGTM development image rather than operating five independent services during the first experiment. This is a reproducible *recipe to try*, not infrastructure shipped or validated against your machine by this documentation project.

!!! warning "Local development only"
    This lab uses Grafana's development credentials and ephemeral storage. Keep ports on loopback, use synthetic data first, and do not deploy it to a shared or production cluster. It has no custom content-redaction gateway, configured retention guarantee, or production access controls.

## Components and boundaries

```text
Laptop Copilot CLI
    -> 127.0.0.1:4318 (Tilt port forward)
    -> LGTM's built-in OTel Collector
    -> Tempo: traces / Prometheus-compatible metrics / Loki: logs

Browser -> 127.0.0.1:3000 -> Grafana
Browser -> 127.0.0.1:10350 -> Tilt
```

Use the bundled metrics data source provisioned by the selected image. The LGTM implementation can evolve; check image release notes instead of assuming a production architecture from the acronym.

Tilt starts services and keeps forwarding alive. It **cannot change the environment of an already-running Copilot process**.

## Prerequisites

Install Docker Desktop, enable its Kubernetes cluster, and install `kubectl` and Tilt through approved channels. Docker Desktop licensing may matter for a large enterprise; this is not a recommendation to distribute it without procurement review.

```sh
docker version
kubectl config current-context
kubectl --context docker-desktop get nodes
tilt version
```

The expected Kubernetes context is `docker-desktop`. Do not switch or modify a shared context automatically. Ensure ports 3000, 4318 and 10350 are available.

## Create an isolated lab directory

In a private directory outside any repository containing session data, save the following as `Tiltfile`:

```python
if k8s_context() != 'docker-desktop':
    fail('This lab only supports the docker-desktop context.')

k8s_yaml('lgtm.yaml')
k8s_resource(
    'lgtm',
    port_forwards=[
        port_forward(3000, 3000, host='127.0.0.1'),
        port_forward(4318, 4318, host='127.0.0.1'),
    ],
    links=[link('http://127.0.0.1:3000', 'Grafana')],
)
```

Save this as `lgtm.yaml` in the same directory. `0.35.0` was the upstream LGTM release checked for this reader; before standardizing an installer, verify the image's architecture support and pin its digest.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: agent-analytics-lab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lgtm
  namespace: agent-analytics-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: agent-analytics-lgtm
  template:
    metadata:
      labels:
        app: agent-analytics-lgtm
    spec:
      containers:
        - name: lgtm
          image: grafana/otel-lgtm:0.35.0
          ports:
            - containerPort: 3000
            - containerPort: 4318
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "4Gi"
          readinessProbe:
            exec:
              command: ["cat", "/tmp/ready"]
            initialDelaySeconds: 10
            periodSeconds: 5
          volumeMounts:
            - name: data
              mountPath: /data
            - name: loki
              mountPath: /loki
      volumes:
        - name: data
          emptyDir: {}
        - name: loki
          emptyDir: {}
```

The resource settings are an initial laptop budget, not measured performance guarantees. Readiness mirrors the [upstream Kubernetes example](https://github.com/grafana/docker-otel-lgtm/blob/main/k8s/lgtm.yaml). A Pod-local receiver needs to listen on a Pod-reachable address; localhost-only safety is at the host port-forward boundary. Other Pods in this cluster may still reach it, so the cluster must be trusted.

## Start and verify

```sh
tilt up --host 127.0.0.1
```

Leave Tilt running. Open its UI at `http://127.0.0.1:10350`; wait until the deployment is ready. In a second terminal:

```sh
curl --fail --silent --show-error http://127.0.0.1:3000/api/health
```

Open Grafana at `http://127.0.0.1:3000`. The upstream development image documents `admin` / `admin`; change the password when prompted, and never expose this instance publicly.

### Send a synthetic trace

This safe probe uses current timestamps. It exercises OTLP ingestion without a Copilot credential or any source code. Run it in a Bash-compatible shell:

```sh
start_seconds=$(date +%s)
end_seconds=$((start_seconds + 1))

curl --fail-with-body --silent --show-error \
  -H 'Content-Type: application/json' \
  http://127.0.0.1:4318/v1/traces \
  --data-binary @- <<EOF
{
    "resourceSpans": [{
      "resource": {"attributes": [
        {"key": "service.name", "value": {"stringValue": "agent-analytics-smoke"}}
      ]},
      "scopeSpans": [{
        "scope": {"name": "agent-analytics-probe"},
        "spans": [{
          "traceId": "11111111111111111111111111111111",
          "spanId": "2222222222222222",
          "name": "invoke_agent smoke",
          "kind": 1,
          "startTimeUnixNano": "${start_seconds}000000000",
          "endTimeUnixNano": "${end_seconds}000000000",
          "attributes": [
            {"key": "gen_ai.operation.name", "value": {"stringValue": "invoke_agent"}},
            {"key": "gen_ai.conversation.id", "value": {"stringValue": "synthetic-smoke"}},
            {"key": "gen_ai.agent.name", "value": {"stringValue": "smoke"}}
          ],
          "status": {"code": 1}
        }]
      }]
    }]
  }
EOF
```

In Grafana Explore, select Tempo and retrieve trace ID `11111111111111111111111111111111`, or search the last few minutes for `agent-analytics-smoke`. This fixed ID is a one-off connectivity probe, not a load generator or replay test. An HTTP success only means the receiver accepted the request; **the trace must also be readable in storage**. Check for any OTLP `partialSuccess` rejection and inspect Tilt logs if it is absent.

This tests HTTP/JSON acceptance by the local collector, not the CLI's protobuf exporter, metrics pipeline, or content policy. Complete the [CLI smoke task](copilot-cli.md) for those checks.

## Where to look first

| Need | Grafana route | What to inspect |
| --- | --- | --- |
| One interaction | Explore -> Tempo | Invocation tree, child chat/tool spans, errors |
| Cross-session latency | Explore -> metrics data source | Model and tool duration histograms |
| Token volume | Metrics or Tempo search | Input/output usage at one non-overlapping grain |
| Collector problems | Tilt resource logs | Export failures, timeouts, memory pressure |
| Agent conversation view | Not provided out of the box | See the [viewer proposal](../proposals/viewer.md) |

## Stop and storage behavior

Press Ctrl+C to stop Tilt and its forwards. That does **not necessarily delete deployed resources**. From the lab directory, use:

```sh
tilt down
```

Review the resources before deleting them. This recipe owns only its dedicated namespace/deployment. `emptyDir` data survives a container restart inside the same Pod, but is lost when the Pod is replaced or deleted. It is neither durable storage nor a seven-day retention implementation.

The proposed packaged version should use a bounded persistent volume, explicit TTLs and an exact-scope purge command. Do not add persistence before deciding the privacy policy.

## Simpler alternative: Docker without Kubernetes

For participants who do not already use Kubernetes, try the same development image directly:

```sh
docker run --rm --name agent-analytics-lgtm \
  -p 127.0.0.1:3000:3000 \
  -p 127.0.0.1:4318:4318 \
  grafana/otel-lgtm:0.35.0
```

No host data volume is mounted; stopping/removing the container loses the telemetry. The same capture guide applies. A future launcher should support this path rather than making every engineer install Tilt and Kubernetes.

Sources: [Grafana local LGTM guide](https://grafana.com/docs/opentelemetry/docker-lgtm/), [Tilt API](https://docs.tilt.dev/api.html).
