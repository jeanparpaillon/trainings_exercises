# Module 3 — scaling and high availability

Exercises for module 3 of **F021**. The slides are in the `trainings` repo,
`f021/slides/pages/module3_scaling_ha.md`; every step here names the slide
it belongs to.

| | Lab | Slides | Starts from | ~ |
| --- | --- | --- | --- | --- |
| [autoscale/](autoscale/) | measure, right-size, autoscale: throttling, OOM, VPA, HPA on CPU, HPA on request rate | `perf_lab1.md` | `module1/lab1/step3-balancing` | 75 min + debrief |
| [harden/](harden/) | harden the application: baseline, probes, graceful shutdown, replicas and budgets; timeouts and fallback (optional) | `failure_lab1.md` | `autoscale/step6-hpa-rps` | 90 min |

Both labs are cumulative kustomize overlays on Bookinfo; `harden/` continues
from the end of `autoscale/`. Every path is relative to this directory:

```sh
export NS=<your-namespace>
cd module3
```

## Starting state

The namespace as module 2 left it: Bookinfo (with its HTTPRoute), WordPress
with MySQL as a StatefulSet, **no NetworkPolicy**.

```sh
kubectl -n "$NS" get networkpolicy               # must be empty: k6 and Prometheus need an open namespace
kubectl -n "$NS" scale deploy/wordpress sts/mysql --replicas=0
```

WordPress stays at 0 for the whole module — see the quota below — and comes
back at the end of `harden/`, with its data (the claim `data-mysql-0` is
kept).

## Quota

The `trainee` quota is **1 CPU requested** (2 GiB requested, 4 GiB of memory
limits). Both labs are sized for it, with WordPress at 0:

| Moment | CPU requested |
| --- | --- |
| `autoscale/step1-baseline` (LimitRange defaults, 50m per container) | ~310m |
| `autoscale/step6-hpa-rps` (right-sized, productpage meshed) | ~520m, + k6 |
| `harden/step4-spread`, productpage ×2, reviews-v2 ×2, meshed k6 running | ~840m |
| same, during a rollout (one surge pod) | ~950m |

Hence HPAs with `maxReplicas: 3`, only `reviews-v2` with two replicas, and
the proxies' requests set by annotation. A pod that does not appear:
`kubectl -n "$NS" describe quota trainee` and the ReplicaSet's events
(`FailedCreate … exceeded quota`). Leftovers from module 1 (`first-deploy`,
`cronjob`) eat into it: delete them.

## On the shared cluster

What the labs rely on, checked on the cluster (trainer, before the session):

```sh
kubectl top pods -n "$NS"                                       # metrics-server
kubectl -n vpa get deploy vpa-recommender                       # VPA, recommendations only
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/linkerd/pods/*/requests_per_second" | jq '.items | length'
```

- **One k6 ramp at a time** in `autoscale/`: 13 ramps on one node measure the
  node, not the service. The trainer calls the slots.
- **Single node**: no drain in `harden/step4-spread` — attendees call the
  eviction API on their own pods. The drain is a trainer demo on a
  multi-node kind cluster (`../module2/kind.yaml`).
- **Linkerd**: proxies are native sidecars, so the meshed k6 Job of
  `harden/` completes when k6 exits. `linkerd viz tap` (harden step 3)
  works with the trainees' rights.
- **Grafana** (*Explore*) for CPU throttling, autoscale step 2:
  `https://grafana.srv2052563.hstgr.cloud/`, console login.

## End state — what module 4 expects

```sh
kubectl -n "$NS" delete job k6 --ignore-not-found
kubectl -n "$NS" apply -k harden/step4-spread
kubectl -n "$NS" scale deploy/wordpress sts/mysql --replicas=1
```

Bookinfo hardened (probes, `preStop`, two replicas and PDBs for productpage
and reviews-v2), WordPress back. `../module4/troubleshoot/reset` returns to
exactly this state.
