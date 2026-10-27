# Module 4 — monitoring, logging and troubleshooting

Exercises for module 4 of **F021**. The slides are in the `trainings` repo,
`f021/slides/pages/module4_monitoring.md`.

| | Lab | Slides | ~ |
| --- | --- | --- | --- |
| [monitoring/](monitoring/) | your WordPress in Prometheus and Grafana: what is measured already, an exporter and the edge's metrics, alerts, a dashboard as code | `monitoring.md`, then `lab_monitoring.md` | 60 min |
| [troubleshoot/](troubleshoot/) | troubleshooting scenarios: `break`, find it with the method, `check` | `troubleshooting.md`, then `lab_troubleshooting.md` | 60 min |

No logging lab: no log stack on the shared cluster, `kubectl logs` only
(`logging.md`). The two labs chain: troubleshooting starts from the end of
monitoring, so the alerts written in the first lab fire during the second.
Every path below is relative to this directory:

```sh
export NS=<your-namespace>
cd module4
```

## Starting state

The namespace as module 2 left it: WordPress with MySQL as a StatefulSet
and its data, the toolbox, the Ingress and the HTTPRoute
(`module2/network/step2-gateway`), **no NetworkPolicy** — Prometheus,
in namespace `monitoring`, must reach the MySQL exporter.

```sh
kubectl -n "$NS" get pods,pvc              # wordpress, mysql-0, toolbox Running; data-mysql-0 Bound
kubectl -n "$NS" get networkpolicy         # must be empty
```

The monitoring lab applies on top of it. Behind, or lost during the
troubleshooting lab? `troubleshoot/reset` brings the namespace to the end
of the monitoring lab, with your own rights. It needs what you rendered or
created by hand in modules 1 and 2: the WordPress Ingress, the HTTPRoute,
the WordPress Secret (and its `db.env`). It renders the monitoring lab's
two files itself if they are missing, and removes the NetworkPolicies of
the module 2 network lab if they are still there.

`break` and `check` load the blog through the Ingress, from wherever they
run: the web console on the shared cluster (`wordpress.<ns>.195.35.2.222.nip.io`),
or with `export NIP=127.0.0.1.nip.io` on a local kind cluster.

## For the trainer

Before the session, on the shared cluster:

- **Traefik is scraped**: the monitoring lab's edge metrics and its
  `WordPressErrorRate` alert read `traefik_service_requests_total`, which
  only reaches Prometheus through the platform PodMonitor
  `traefik/traefik` (`shared-cluster/infrastructure/configs/traefik-metrics.yaml`).
  Check in Grafana's Explore: `count(traefik_service_requests_total)` > 0.
- **Grafana logins**: `make grafana-users` in `shared-cluster/` (console
  login and password, role Editor).
- **Logging**: no log stack is installed (`shared-cluster/README.md`):
  `kubectl logs` only, in the labs and in `logging.md`.
- **Scenario 6** (DNS blocked by a NetworkPolicy) needs the CNI to enforce
  NetworkPolicy: same check as the module 2 network lab, step 4.
- **Scenario 5** (rollout stuck on the quota) computes its memory request
  from the quota's `status.used` at `break` time: run it with no module 1
  leftovers (`first-deploy`, `cronjob`) in the namespace, or the margin is
  off.
- Run the monitoring lab and the seven scenarios once in a trainee
  namespace: `break n`, check the symptom, apply the fix of the *For the
  trainer* section of `troubleshoot/README.md`, `check n`, `reset`.

## Former material

[`former-day4.md`](former-day4.md) is the former day 4, security and
advanced governance: the starting point of the module 5 labs, not used as
is.
