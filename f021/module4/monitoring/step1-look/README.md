# Step 1 — look: what is measured already

**Slide:** Lab — monitoring: look · **~15 min**

Nothing in WordPress or MySQL produces metrics. Yet the platform already
measures your pods: the kubelet (cAdvisor) for CPU and memory,
kube-state-metrics for what the Kubernetes objects say. This step adds
steady traffic on the blog, through Traefik, so that something moves.

```sh
kubectl -n "$NS" apply -k monitoring/step1-look
kubectl -n "$NS" logs deploy/loadgen -f         # silent while all goes well
```

## Dashboards

Grafana → *Dashboards* → **Kubernetes / Compute Resources / Namespace
(Pods)**, namespace = yours:

- CPU and memory per pod, **against requests and limits** — which pod is
  closest to its memory limit?
- then click a pod: **Kubernetes / Compute Resources / Pod** — per
  container, throttling.

## Explore

Grafana → *Explore* → data source *Prometheus*, one query at a time (type
your namespace):

```text
# memory actually used, per pod — what the OOM killer compares to the limit
sum by (pod) (container_memory_working_set_bytes{namespace="<ns>", container!=""})

# CPU, per pod, in cores
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="<ns>", container!=""}[5m]))

# what Kubernetes says: restarts, available replicas
kube_pod_container_status_restarts_total{namespace="<ns>"}
kube_deployment_status_replicas_available{namespace="<ns>"}

# who is scraped in your namespace: nothing yet
up{namespace="<ns>"}
```

## Questions to answer before moving on

- Which of these numbers tells you whether **the blog works** for a
  reader? None — why?
- `container_memory_working_set_bytes` or `container_memory_usage_bytes`:
  which one does the OOM killer act on?
- Scale `wordpress` to 0 for a minute, then back to 1: which query shows
  it, and how long after?
