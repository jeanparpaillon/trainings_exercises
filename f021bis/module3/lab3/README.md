# Lab 3 — Prometheus metrics in Zabbix

**Slides:** *Zabbix and the Prometheus stack*, *Collecting Prometheus
metrics in Zabbix* (`zabbix_prometheus.md`), then *Lab 3*
(`lab_zabbix_prometheus.md`) · **~65 min**

The Kubernetes templates of lab 2 see nodes, pods and controllers, not
whether an application answers, how fast, how often with an error. Here an
application's own `/metrics` is collected by Zabbix — one HTTP request,
many items, discovery on its labels — and moved into a template of your
own, exported to Git.

| Step | | ~ |
| --- | --- | --- |
| [step1-podinfo](step1-podinfo/) | an application with `/metrics` | 10 min |
| [step2-items](step2-items/) | one master item, dependent items | 20 min |
| [step3-lld](step3-lld/) | discovery from Prometheus metrics | 15 min |
| [step4-template](step4-template/) | a template of your own | 15 min |
| [step5-export](step5-export/) | export, commit | 5 min |

| File | What it is |
| --- | --- |
| [`step1-podinfo/values.yaml`](step1-podinfo/values.yaml) | podinfo's Helm values: one replica, off the control plane |
| [`load.yaml`](load.yaml) | Deployment `load` in `podinfo`: ~3 requests/s to the Service, `/` mostly, one in ten `/status/500`, one in ten `/delay/1`; the mix in `PATHS` (lab 4 changes it) |
| [`solution/`](solution/) | `~/m3` at the end of the lab: lab 2's, plus `templates/podinfo.yaml` (the template) and `hosts/podinfo.yaml`, with `${ZBX_USER}` in place of your name and `${UUID:…}` in place of the uuids (`lab0/render` makes them yours) |

**Start**: lab 2 done (or `make catch-up-lab2`), from `module3/`:

```sh
cd ~/trainings_exercises/f021bis/module3
source versions.env
source ~/.zabbix/user.env
kubectl config current-context        # kind-mon-<name>
```

**End state** (start of lab 4): podinfo, one replica on the worker, under
load in `podinfo`; template `<name> podinfo by HTTP` in template group
`<name>` — the step 2 items, the two discovery rules of step 3, p95, and
*rollout stuck* from kube-state-metrics — linked to host `<name>
podinfo`, monitored by proxy `<name>`; `~/m3` tagged `lab3`.

Catch-up (from `module3/`): `make catch-up-lab3` — `catch-up-lab2`, plus
podinfo and its load, and the template imported (made to match the
solution) before the hosts.

## Validated on the server

2026-10-20, in `console-jean`, on `mon-jean` at the end of lab 2: every
step through the API (what the step files have the UI do; the UI itself
was not clicked through), step 5's commands as written, then `make
catch-up-lab3` on the existing `mon`: 1 min 11 s, every item collecting
again within 3 min. Measured there:

- **One replica, not two**, against the spec: through the Service, two
  podinfo pods answer the master item in turn. `started` alternated
  between the two processes' start times, *requests per second* read
  0.9–2.3 for a true ~3.1, *5xx per second* 0.10–0.47 for ~0.31 — no
  error, nothing red, plausible numbers. With one replica: 3.10, 0.27–0.33,
  mean latency 0.097 s (expected ~0.1), 89–90 % under 0.5 s (expected
  90 %). Step 4 keeps the two replicas as the experiment that shows it.
- **p95 is possible in Zabbix**, against the slides and the spec:
  `bucket_percentile()` (calculated items, 7.0) over discovered bucket
  items — 1.70–1.72 s, against 1.7 s computed by hand; the mean was
  0.09 s. The bucket rule must read **one** series
  (`{path="metrics"}`), or it errors on duplicate keys.
- **Linking adopts**: linking the template to the host while the host
  still had its own items with the same keys **succeeded**, and kept the
  item IDs, so the history: the spec's "link, then delete the host's
  items" becomes "link". Items have *Copy* in the UI; discovery rules do
  not (the list offers only *Delete*): step 4 recreates the two rules.
- **A pattern that matches nothing is an error**, `function sum`
  included: the 5xx item is unsupported until podinfo's first 500.
- **Master down** (podinfo scaled to 0): every item *unsupported* with the
  master's error, `Failed to connect to podinfo.podinfo.svc:9898`, the
  calculated ones with `item … is not supported`; **no problem raised**.
- **The spec's kube-state-metrics example is already in the shipped
  template** (`kube.deployment.replicas_unavailable[…]`); replaced by
  `kube_deployment_status_condition{condition="Progressing",
  status="false"}`, which it does not read. Stuck rollout (bad image,
  `progressDeadlineSeconds: 30`): 1 within 50 s; the shipped template
  raised *Pod is not healthy* (High) and *ReplicaSet mismatch* 25 s later.
  podinfo was down meanwhile — the chart's `maxUnavailable: 1` — with the
  Deployment `Available=True`.
- `path` is podinfo's **route** (`root`, `status`, `delay`, `healthz`,
  `readyz`, `metrics`, `version`…), so discovering on it is bounded;
  `metrics` is Zabbix's own read, `healthz`/`readyz` the kubelet's probes.
- kube-state-metrics' `/metrics` is ~216 KB, 1277 series, on a cluster
  with nothing but the system, the chart and podinfo.
- **A template import needs a `uuid`** (`the tag "uuid" is missing`), a
  version 4 one (`UUIDv4 is expected`), and uuids are server-wide: the
  solution has `${UUID:<seed>}`, which `lab0/render` makes per trainee
  (md5 of name and seed, version digits set). The `templates` target
  deletes the tenant's templates before the import, since the one made in
  the UI has other uuids.

**For lab 4**: with lab 2's *keep lost resources 1 h* on *Pod discovery*,
the stuck rollout's *Pod is not healthy* stayed **open after the pod was
gone** (the pod's items disabled, not deleted, and the problem with
them). Expect stale problems in the drill if a pod is replaced.
