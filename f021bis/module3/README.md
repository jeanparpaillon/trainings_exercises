# Module 3 — Monitoring Kubernetes with Zabbix

Exercises for module 3 of **F021bis — Kubernetes in production**. The slides
are in `../../../trainings/f021bis/slides/module3.md`; every lab here names
the slides it belongs to, and the slides point back with
`📖 module3/README.md — Lab N`.

> **Status: labs 1 to 4 written and validated on the server**
> (2026-10-20, `console-jean`), with `lab0/`, `versions.env`, `make
> catch-up-lab1` to `-lab4`; findings in each lab's README. One
> open decision: tenants cannot delete their parent hosts once discovery
> has run ([`lab2/README.md`](lab2/README.md#validated-on-the-server)).
> Labs 3 and 4 depart from their specification where the run disagreed
> with it (lab 3: one podinfo replica, p95 computed in Zabbix, another
> kube-state-metrics metric; lab 4: the proxy moved off the worker before
> the drill, *no data* not on the master item):
> [`lab3/README.md`](lab3/README.md#validated-on-the-server),
> [`lab4/README.md`](lab4/README.md#validated-on-the-server). The step
> files give UI paths; the runs went through the API.

| | Lab | Session | ~ |
| --- | --- | --- | --- |
| [lab1/](lab1/) | connect a cluster: proxy and agents with the Helm chart, nodes by hand | 1 | 65 min |
| [lab2/](lab2/) | discover the cluster: Kubernetes templates, LLD, control plane | 2 | 75 min |
| [lab3/](lab3/) | Prometheus metrics in Zabbix: kube-state-metrics, an application, a template | 3 | 65 min |
| [lab4/](lab4/) | alert, dashboard, incident drill | 4 | 55 min |
| [lab0/](lab0/) | chart, images, Zabbix credentials; once before session 1 | — | — |

The trainees **run Zabbix in production** already: hosts, items, triggers,
templates, actions, proxies are known. The labs do not teach Zabbix; they
teach what changes when the monitored thing is a Kubernetes cluster — a
proxy inside it, objects that come and go (discovery instead of hosts by
hand), metrics in Prometheus format, and alerts that must not page for
every pod.

The module's recommended approach, which the labs follow: **Zabbix stays the
monitoring and alerting tool** (nodes, on-call), and **Prometheus metrics are
collected by Zabbix** rather than by a second stack. The alternative
(Alertmanager forwarding to Zabbix) is a slide in session 4, not a lab.

## Thread of the module

One kind cluster per trainee, **`mon-<name>`** (`$CLUSTER`, "`mon`" below),
in their own console, from lab 1 to lab 4, monitored by the room's Zabbix server through the trainee's own proxy:

- **lab 1** creates `mon`, installs the proxy and the agents, and monitors
  the two nodes as hosts created **by hand** — the way they do it today;
- **lab 2** replaces those hosts by **discovery** (nodes, cluster state,
  control plane) and watches objects appear and disappear;
- **lab 3** adds what the templates do not cover: an application's
  `/metrics`, in a template of their own, exported to Git;
- **lab 4** alerts on all of it, builds the cluster dashboard, then
  two faults break `mon`, one in the control layer (a node) and one in the
  workload (HTTP 500s), and the trainee finds them **from Zabbix only**.

| Cluster | What | Nodes | Used by | Lifetime |
| --- | --- | --- | --- | --- |
| `mon-<name>` | kind, `KIND_NODE` | 1 control plane (untainted) + 1 worker | labs 1 → 4 | until the end of the module |

Each lab's end state is the next one's start. A `make catch-up-labN` target
must rebuild it (see [Conventions](#conventions)).

## Where the labs run

| Role | What | Where |
| --- | --- | --- |
| Zabbix server, web UI | one for the room, 7.0 LTS | shared cluster, namespace `zabbix`; UI `https://srv2052563.hstgr.cloud/zabbix/`; trapper `195.35.2.222:10051` (see [`../shared-cluster/README.md`](../shared-cluster/README.md#zabbix)) |
| Zabbix proxy | one per trainee, **active**, named after their console login (`<name>`, e.g. `user1`) | a pod in `mon` |
| Zabbix agent 2 | DaemonSet, `hostNetwork`, one per node | `mon` |
| kube-state-metrics | deployed by the chart | `mon` |
| the trainee | web UI as user `<name>`; `kubectl`, `helm`, `curl` in the console | console |

**Alone, in their own console**: there are 3 trainees, so each runs their
own `mon` (see [Size](#size-trainer)), which carries the four labs. Lab 4's
drill breaks it twice, with `lab4/break control` (worker node paused) and
`lab4/break workload` (podinfo answering 500).

The proxy reaches the server by its **IP**, never the host name (it resolves
to `127.0.1.1` inside every container of the server), and the server only
accepts proxies declared in it: autoregistration is off and port 10051 is
open to the Internet. Hence the per-trainee proxy and PSK below.

### The shared server: what each trainee gets (trainer)

One Zabbix for the room means every trainee sees the same frontend. Each is
confined to their own groups, so that nobody edits another trainee's hosts
or the global templates:

| Object | Name | Created by |
| --- | --- | --- |
| proxy | `<name>`, active, PSK identity `<name>`, encryption PSK only | trainer (`lab0`) |
| host group | `<name>` | trainer |
| template group | `<name>` | trainer |
| user group | `<name>`: read-write on both groups above, read on `Templates/*` | trainer |
| user | `<name>`, role *Admin* (not *Super admin*), in user group `<name>` | trainer |
| media type | `Lab webhook`, one for the room: a webhook that logs the message and returns OK (lab 4); a media of it on each user | trainer |
| the Kubernetes and Linux templates | as shipped with 7.0 (`Templates/Applications`, `Templates/Operating systems`, …) | imported by the server at first start; linked by the trainees, never edited |

**Everyone sees everyone's hosts**: each user group reads the other
trainees' host groups and `Applications`, where the shipped Kubernetes
templates put the hosts they discover (lab 2); it writes only its own two
groups. Seeing the others' clusters is fine in this room, and needed: a
discovered host sits in groups created by discovery, which no right set
beforehand can name.

Everything a trainee creates — hosts, their lab 3 template (`<name>
podinfo by HTTP`), dashboards, actions — goes in their groups, and **starts with
their name**: host, template, action and dashboard names are unique across
the server (hosts and templates share one), so two trainees' `podinfo`
hosts would collide. Lab 4's actions
are filtered on host group `<name>`; the step file says why (one server, one
action table: an action without a filter fires for everyone).

**Written**: `make zabbix-users` in `../shared-cluster/` (`bin/zabbix
users`, run on the server like the other `bin/zabbix` commands), for every
console login in `/root/users/consoles.txt` (`NAMES="user1 user2"` for
some), through the JSON-RPC API. Tested against a local kind cluster with
the same manifests (2026-10-19): create, re-run, the trainee user's rights,
delete. Re-runnable: creates what is missing, never rotates a PSK or a
password that exists. It stores a Secret `zabbix-user` in **the trainee's
namespace on the shared cluster**: `name`, `password`, `psk_identity`, `psk`, `server`
(`195.35.2.222:10051`), `url`. The console reads it with its
`training-f021bis` context:

```sh
kubectl --context training-f021bis get secret zabbix-user -o jsonpath='{.data.psk}' | base64 -d
```

`make -C lab0 credentials` turns that into `~/.zabbix/user.env` (mode 600:
`ZBX_USER`, `ZBX_PSK_IDENTITY`, `ZBX_PSK_FILE`, `ZBX_PASSWORD`, and
`CLUSTER=mon-$ZBX_USER`) and
`~/.zabbix/user.psk`, outside the repo. Nothing secret goes in Git.

`make zabbix-users-delete` removes, per trainee, their maintenances, the
actions that name their user, user group or host group, their dashboards and
maps, their hosts and templates, then the proxy, user, groups and Secrets. A
trainee reads the others' hosts and proxy names, and changes only their own. The trainer's own login (`jean`) gets a tenant too,
for the demos.

## Conventions

- **Run everything from `module3/`**, after `source versions.env` and
  `source ~/.zabbix/user.env`. Paths in the step files are relative to it.
- **Steps are directories**, `labN/stepM-<name>/README.md`, as in modules 1
  and 2: goal, what to do (UI path or command), what to look for, questions
  to answer before moving on. Given files (Helm values, manifests) sit next
  to the step file.
- **The UI is the tool.** The trainees know the Zabbix frontend; step files
  give the menu path (*Data collection → Hosts*, *Monitoring → Latest
  data*) and the values to enter, not screenshots. Each step names one
  check that does not need the UI (`kubectl`, `zabbix_get` from the proxy
  pod, the API with `curl`) so that a broken UI is not a dead end.
- **Zabbix configuration is code at the end of each lab**: the trainee exports
  its hosts and templates as YAML (`configuration.export` through
  `lab0/zapi`; the UI's *Export* downloads to the laptop, not the console)
  into `~/m3/`, a Git repo from lab 1 on, tag `lab1`…`lab4`. The catch-up
  targets import those exports back; they are also the solutions
  (`labN/solution/`, YAML with `${ZBX_USER}`, `${CLUSTER}`, `${CP_IP}`… in
  place of the trainee's values, filled in by `lab0/render`: the console
  has no `envsubst`; `${UUID:<seed>}` for a template's uuids, one set per
  trainee). **A tenant cannot `configuration.import` a host linked
  to a shipped template** (it only reads them: `Template "…" for host "…"
  does not exist`); `lab0/import` imports without the links and adds them
  with `host.massadd`, which is allowed. Templates of their own (lab 3)
  are in their template group, which they write.
- **The API from the console**: `lab0/zapi <method> [params]` (login,
  call, logout), on `ZBX_API` = the frontend's Service,
  `http://zabbix-web.zabbix.svc:8080/` — not the public URL, whose host name
  resolves to `127.0.1.1` in every container of the server **(to validate
  from a console)**. The trainees' role (*Admin*) has **no
  *Administration* menu**: proxies are read with `proxy.get`, the trainer
  shows *Administration → Proxies*.
- **Data takes time.** Zabbix updates are not instant: discovery runs every
  hour by default, items every minute. Step files say which intervals to
  lower for the lab (on the host's macros or with *Execute now*), and how
  long to wait before deciding something is broken. Never wait on a 1 h
  discovery in a lab.
- **Kubernetes side through `kubectl`, Zabbix side through the UI**: when a
  check disagrees, the step file says which one is the truth (the cluster),
  and what lag is normal.
- **Contexts.** kind switches to `kind-mon-<name>`; the shared cluster is
  `training-f021bis`, used only to read the trainee's Secret. Check
  `kubectl config current-context` before anything destructive.

**Catch-up** (from `module3/`): `make catch-up-lab1`, `-lab2`, `-lab3`
create `mon` if it is missing (cluster, images, chart with the trainee's
PSK, podinfo from lab 3 on), replace `~/m3` by `labN/solution/` rendered
for the trainee and their nodes' current IPs, delete the hosts of host
group `<name>` on the server and import `~/m3/hosts/` with `lab0/import`.
`catch-up-lab1` is written: ~1 min 10 s from no cluster, ~50 s on an
existing one (laptop). `catch-up-lab3` also installs podinfo and its load,
and imports `~/m3/templates/` before the hosts. The pieces are targets
(`mon`, `m3 LAB=…`, `chart`, `podinfo`, `templates`, `hosts`) for the next
labs to reuse. Keep them in sync when an end state
changes.

## Prerequisites

| Tool | Where |
| --- | --- |
| `kubectl`, `kind`, `helm` (v4), `docker`, `curl`, `git` | console image |
| `jq`, `nc`, `perl` | console image (`jq`, `netcat-openbsd` in its Dockerfile; `perl` in every Ubuntu image). No `envsubst`: `lab0/render` |
| `zabbix_get` | in the proxy image (`kubectl exec` into the proxy pod); not installed in the console |
| Zabbix and podinfo Helm charts | `lab0 chart`: the `.tgz` at `ZABBIX_CHART_VERSION` and `PODINFO_CHART_VERSION` into `lab0/charts/` (git-ignored), installed from the file (no network dependency on the day) |
| images | `lab0 pull`: proxy, agent2, kube-state-metrics, podinfo, `KIND_NODE`, into the console's Docker, single platform; `lab0 load` in lab 1 (`kind load image-archive`: `kind load docker-image` fails with the containerd image store) |

### Versions

All in [`versions.env`](versions.env) (same format as modules 1 and 2):

| Variable | Value | Notes |
| --- | --- | --- |
| `KIND_NODE` | module 1's `KIND_NODE_TO` (v1.37.0) | already pulled in every console |
| `ZABBIX_VERSION` | `7.0.31` | **must match the server** (`../shared-cluster/zabbix/kustomization.yaml`): same major for the proxy to be accepted; same tag for the agents, to keep one version in the room |
| `ZABBIX_CHART`, `ZABBIX_CHART_VERSION` | `zabbix-helm-chart` `1.3.4` | official chart, repository `ZABBIX_CHART_REPO` = `https://cdn.zabbix.com/zabbix/integrations/kubernetes-helm/7.0`; appVersion 7.0.17, image tags overridden. The older name `zabbix-helm-chrt` stops at 1.2.4. Release `zabbix` → `zabbix-zabbix-helm-chart-*`, the endpoint names the 7.0 templates default to |
| `KSM_VERSION` | `v2.9.2` | the chart's dependency (kube-state-metrics chart 5.7.0); the cluster state template relies on its metric names. Not run yet: it crash-looped on the laptop for lack of inotify instances, see lab 1 |
| `PODINFO_CHART`, `PODINFO_CHART_VERSION` | `podinfo` `6.15.0` | module 2's, repository `PODINFO_CHART_REPO` = `https://stefanprodan.github.io/podinfo`; podinfo exposes Prometheus metrics on `:9898/metrics`. The chart hard-codes `maxUnavailable: 1` (lab 3 step 4) |

## Lab 1 — Connect a cluster to Zabbix (session 1)

Slides: *Zabbix for Kubernetes: architecture*, *Lab 1 — Connect a cluster
to Zabbix*. 65 min, then a 10 min debrief.

| | Step | ~ |
| --- | --- | --- |
| 1 | cluster `mon`, Zabbix credentials, `~/m3` | 10 min |
| 2 | proxy and agents with the Helm chart | 20 min |
| 3 | the proxy, seen from the server | 10 min |
| 4 | the nodes as hosts, by hand | 20 min |
| 5 | export, commit | 5 min |

**Written**: [`lab1/`](lab1/) — the step files are the reference; this is
their outline. Start: `make -C lab0 credentials` then `make -C lab0 check`
green (the trainer ran `make zabbix-users` and `make -C lab0
pull-consoles`).

1. **step1-cluster** — `make -C lab0 credentials`, `kind create cluster
   --name "$CLUSTER" --config lab1/kind.yaml`, `make -C lab0 load`; log in
   to the UI as `<name>`, see the empty host group and the others';
   `git init ~/m3`. Questions: what `<name>` sees and changes of the
   others, why enough for a lab and not for production; why `mon-<name>`.
2. **step2-chart** — complete `lab1/step2-chart/values.yaml` into
   `~/m3/values.yaml` (image tags, `ZBX_HOSTNAME`, `ZBX_SERVER_HOST`,
   `ZBX_TLSCONNECT=psk`, `ZBX_TLSPSKIDENTITY`, `ZBX_TLSPSKFILE=psk`); Secret
   `zabbix-proxy-psk` from `~/.zabbix/user.psk`, mounted by the given
   `extraVolumes` (the chart's `env` takes literal values only); `helm
   install zabbix lab0/charts/zabbix-helm-chart-1.3.4.tgz -n monitoring`.
   The traps, with the log lines seen on the dry run, are in the step file.
3. **step3-proxy** — the proxy's `state`, `lastaccess`, `version`,
   `compatibility` **through the API** (`lab0/zapi proxy.get`): the Admin
   role has no *Administration → Proxies*. Scale the proxy to 0 for two
   minutes: offline by 90 s, back in ~15 s with a **new** SQLite database
   (`emptyDir`) — nothing collected, nothing buffered. Question: why a proxy
   per cluster; the buffer settings (defaults apply: the entrypoint drops
   the image's `ProxyBufferMode=hybrid`).
4. **step4-nodes** — hosts `$CLUSTER-control-plane` and `$CLUSTER-worker` by
   hand (group `<name>`, monitored by proxy `<name>`, agent interface =
   `InternalIP`:10050, *Linux by Zabbix agent*); `zabbix_get` from the
   proxy pod; compare with `free`, `nproc`, `/proc/uptime`. Then **the
   buffer**, moved here from step 3 (there was no data to buffer there):
   `lab1/step4-nodes/cut.yaml`, a NetworkPolicy cutting only proxy →
   server (kindnet enforces it), two minutes, lifted: no gap in the
   history. Questions as before (whose kernel; DaemonSet vs package;
   module 2's role).
5. **step5-export** — `configuration.export` into `~/m3/hosts/`, commit,
   tag `lab1`. Questions: the IPs (the nodes swapped them on re-creation),
   and why the tenant cannot import its own export back.

**End state** (start of lab 2): `mon` with the chart in `monitoring`; proxy
`<name>` connected; two hand-made node hosts collecting data; `~/m3` tagged
`lab1`.

**Debrief** (10 min): proxy *last seen*, what the Linux template shows on a
kind node, how long the hosts took to fill.

## Lab 2 — Discover the cluster (session 2)

Slides: *Discovering Kubernetes: templates and LLD*, *Lab 2 — Discover the
cluster*. 75 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | token and macros | 10 min |
| 2 | nodes by discovery | 15 min |
| 3 | cluster state | 15 min |
| 4 | objects come and go | 15 min |
| 5 | the control plane | 15 min |
| 6 | export, commit | 5 min |

The two 7.0 templates the lab uses, read off a 7.0.31 server (all six
`Kubernetes … by HTTP` templates are shipped: nodes, cluster state, API
server, controller manager, scheduler, kubelet):

| Template | Goes on | Reads | Creates |
| --- | --- | --- | --- |
| *Kubernetes nodes by HTTP* | a host `<name> mon nodes`, no interface, monitored by proxy `<name>` | the API, and the agents' Endpoints `{$KUBE.NODES.ENDPOINT.NAME}` (default `zabbix-zabbix-helm-chart-agent`) | host prototype `{#NAME}` per node, linked to *Linux by Zabbix agent*; node conditions, allocatable, pods per node |
| *Kubernetes cluster state by HTTP* | a host `<name> mon state`, same | the API and kube-state-metrics, `{$KUBE.STATE.ENDPOINT.NAME}` (default `zabbix-kube-state-metrics`) | deployments, daemonsets, pods, PVCs… items by LLD; host prototypes `API {#NAME}`, `Controller manager {#NAME}`, `Scheduler {#NAME}`, `Kubelet {#NAME}`, each with its template |

Macros, with their defaults: `{$KUBE.API.URL}` =
`https://kubernetes.default.svc.cluster.local:443`, `{$KUBE.API.TOKEN}`
(empty), filters `{$KUBE.LLD.FILTER.{NAMESPACE,NODE,NODE.ROLE,POD.NAMESPACE,PV,KUBELET_NODE}.{MATCHES,NOT_MATCHES}}`,
and the control plane URLs `{$KUBE.{API,CONTROLLER,SCHEDULER}.SERVER.URL}`
(`https://localhost:6443|10257|10259/metrics`, rewritten per discovered
host).

Where discovered hosts go, read off the templates (decided: everyone sees
everyone's hosts, see [The shared server](#the-shared-server-what-each-trainee-gets-trainer)):
host prototypes put them in the fixed group `Applications` and in groups
created during discovery, `{#CLUSTER_HOSTNAME}: Kubernetes/Nodes/Role:
{#ROLES}` and `…: Kubernetes/Components: …`. The trainees **read** them and
cannot edit them (no write on `Applications`): what they change goes on the
parent hosts `<name> mon nodes` / `<name> mon state`, which are theirs.
Discovered hosts are named `{#NAME}`, the node name: hence one cluster name
per trainee, or the second cluster's nodes are never created.

1. **step1-token** — the chart's ServiceAccount and its token Secret: read
   it with `kubectl`; read its ClusterRole (`kubectl describe clusterrole`)
   and say what it can do (read-only, which resources). Check the token
   works from the proxy pod: `curl -k -H "Authorization: Bearer …"
   https://kubernetes.default.svc/api/v1/nodes`. Host macros to set, as a
   list in the step file: `{$KUBE.API.URL}` (`https://kubernetes.default.svc:443`:
   the proxy is in the cluster, it resolves Service names),
   `{$KUBE.API.TOKEN}` (secret macro), and the endpoint names the chart
   created. Question: what does the token give to whoever reads the macro,
   and what does Zabbix do with a *secret* macro?
2. **step2-nodes** — host `<name> mon nodes` with *Kubernetes nodes by HTTP*.
   Lower the discovery interval (macro or *Execute now*). **First delete** lab 1's
   hand-made hosts (exported in lab 1): discovery creates hosts with the
   same names, and fails while those exist (disabling is not enough). Watch
   two hosts appear, in `Applications`, and the other trainees' as they get
   there. Question: lab 1's hosts and these collect the same items; what
   was lost by deleting them (history), which do you keep in production,
   and what happens to each when a node is replaced?
3. **step3-state** — host `<name> mon state` with *Kubernetes cluster state by
   HTTP*. Look at what it discovered: how many items, per object kind.
   Restrict discovery to the namespaces that matter with the template's
   filter macros (`{$KUBE.LLD.FILTER.NAMESPACE.MATCHES}`,
   `{$KUBE.LLD.FILTER.POD.NAMESPACE.MATCHES}`): `default`, `kube-system`, `podinfo` (lab 3's).
   Count the items again. Question: what does that number become on their
   production cluster, and what does it cost on the server?
4. **step4-churn** — given `lab2/step4-churn/` (a Deployment `churn`, 3
   replicas, in `default`). Apply it, wait for discovery, find it in
   *Latest data*. Scale to 0, then delete it. What does Zabbix show
   (items *not discovered anymore*, then deleted after the *keep lost
   resources* period)? Set that period for the lab to 10 minutes on the
   discovery rule override **(to validate: rule-level setting in 7.0,
   `lifetime` / `disable lost resources`)**. Question: with pods that live
   minutes, what should be discovered at all — pods, or their controllers?
5. **step5-control-plane** — the discovered API server host collects; the
   controller manager and scheduler hosts are **unreachable**: kubeadm (and
   kind) bind them to `127.0.0.1`. Find it out from the problem shown,
   then the cause one level down, as in module 1:
   `docker exec $CLUSTER-control-plane grep bind-address
   /etc/kubernetes/manifests/kube-*.yaml`. Fix: `bind-address=0.0.0.0` in
   the two static pod manifests (`docker exec … sed -i`), the kubelet
   restarts them; data arrives. Question: why is that a security decision
   on a production cluster (metrics port open on the node network; their
   authn/authz), and how would they make it permanent (kubeadm
   `ClusterConfiguration`, Kubespray variables from module 2)? etcd's
   metrics (`127.0.0.1:2381`): mentioned, not done.
6. **step6-export** — export `<name> mon nodes` and `<name> mon state` (with their
   macros, minus the token) into `~/m3/hosts/`, delete the lab 1 exports,
   commit, tag `lab2`.

**End state** (start of lab 3): node hosts, cluster state and control plane
discovered under proxy `<name>`, filtered to three namespaces; lab 1's hosts
deleted; `mon`'s control plane serving metrics on `0.0.0.0`.

## Lab 3 — Prometheus metrics in Zabbix (session 3)

Slides: *Zabbix and the Prometheus stack*, *Collecting Prometheus metrics
in Zabbix*, *Lab 3 — Prometheus metrics in Zabbix*. 65 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | an application with `/metrics` | 10 min |
| 2 | one master item, dependent items | 20 min |
| 3 | discovery from Prometheus metrics | 15 min |
| 4 | a template of your own | 15 min |
| 5 | export, commit | 5 min |

**Written**: [`lab3/`](lab3/) — the step files are the reference; this is
their outline. Where it departs from the first specification, the run
decided ([`lab3/README.md`](lab3/README.md#validated-on-the-server)).

1. **step1-podinfo** — podinfo with its chart at `PODINFO_CHART_VERSION`,
   namespace `podinfo`, **one replica** off the control plane
   (`lab3/step1-podinfo/values.yaml`); `lab3/load.yaml`, a Deployment
   running a `curl` loop against the Service, ~3 requests/s, `/` mostly,
   one in ten `/status/500`, one in ten `/delay/1`, the mix in `PATHS`
   (lab 4's `break workload` changes it). Read the raw metrics through a
   port-forward: `http_requests_total{status}`, the histogram
   `http_request_duration_seconds{method,path,status}` (`path` is the
   route: bounded), `process_start_time_seconds`, the Go runtime.
2. **step2-items** — host `<name> podinfo`, no interface, proxy `<name>`.
   Master item *HTTP agent* on `http://podinfo.podinfo.svc:9898/metrics`,
   every 30 s, history *Do not store*. Dependent items, *Prometheus
   pattern* (+ *Change per second* on counters): started, requests/s,
   5xx/s (`{status=~"5.."}`, `sum`), the histogram's `_sum` and `_count`;
   a calculated mean latency; if time, the share under 0.5 s. Traps: a
   pattern that matches nothing is an error, not 0; master down = every
   item unsupported, no problem raised.
3. **step3-lld** — two dependent discovery rules, *Prometheus to JSON*:
   requests per `{#PATH}`/`{#STATUS}` from
   `http_request_duration_seconds_count` (`http_requests_total` has no
   `path`), new items when a new route is hit; the latency buckets
   `{#LE}` from **one** series (`{path="metrics"}`: every series repeats
   the bounds) and a calculated **p95**,
   `bucket_percentile(//podinfo.bucket[*],5m,95)` — 1.7 s, against a 0.09 s
   mean. Question: which label must never be a discovery key.
4. **step4-template** — `<name> podinfo by HTTP` in template group
   `<name>`, macro `{$PODINFO.URL}`; items *Copy*-ed to it, the two rules
   recreated (rules have no *Copy*), then linked: the host's items with
   the same keys are **adopted**, history kept. `{$PODINFO.URL}` on the
   host pointed at the pod's IP, then back. **Two replicas** through the
   Service: `started` flips, the rates are wrong and nothing is red; back
   to one. From kube-state-metrics, what the cluster state template does
   not read: `kube_deployment_status_condition{condition="Progressing",
   status="false"}`, *rollout stuck*; if time, a bad image makes it 1.
5. **step5-export** — the template into `~/m3/templates/podinfo.yaml`, the
   host into `~/m3/hosts/`, commit, tag `lab3`; the `uuid`s are
   server-wide and required by a template import: the solution has
   `${UUID:<seed>}`, rendered per trainee by `lab0/render`. Questions: who owns the file, and how
   it reaches the server (UI, API, `community.zabbix`). Importing it with
   `community.zabbix` is not part of the lab **(to decide: whether lab0
   installs the collection)**.

**End state** (start of lab 4): podinfo, one replica on the worker, under
load in `podinfo`; template `<name> podinfo by HTTP` (step 2 items, two
discovery rules, p95, rollout stuck) linked to host `<name> podinfo`;
`~/m3` tagged `lab3`.

## Lab 4 — Alert, dashboard, incident (session 4)

Slides: *Alerts, dashboards, incidents*, *Alternative: forward Prometheus
alerts to Zabbix*, *Lab 4 — Alert, dashboard, incident*. 55 min.

| | Step | ~ |
| --- | --- | --- |
| 1 | triggers and dependencies | 15 min |
| 2 | an action, a maintenance | 10 min |
| 3 | the cluster dashboard | 10 min |
| 4 | incident drill | 15 min |
| 5 | incident note, export | 5 min |

**Written**: [`lab4/`](lab4/) — the step files are the reference; this is
their outline.

1. **step1-triggers** — the shipped triggers by severity: *node not
   ready* is a **Warning** (on `<name> mon nodes`), *Pod is not healthy*
   High. In `<name> podinfo by HTTP`: macro `{$PODINFO.ERRORS.MAX}` = 1;
   *5xx above … for 2 min* (`min(…,2m)`, High), *no data for 3 min* on
   `podinfo.started` — **not** the master, whose history is not stored:
   `nodata()` on it stays *unknown* —, *rollout stuck*. On host `<name>
   podinfo`, the three depend on *Node [mon-<name>-worker] … not in Ready
   state* (host level: not exported; `lab0/depend`).
2. **step2-action** — media type `Lab webhook`, from the trainer
   (`bin/zabbix users`: a webhook that logs and returns OK; each tenant
   user has a media of it). Action `<name> pages`: `(A or B or C) and (D
   or E)` — host group `<name>`, the two discovered node hosts (read-only
   is enough), severity ≥ Average, or a name containing *Is not in Ready
   state*. A problem on demand: host macro `{$PODINFO.ERRORS.MAX}` = 0.1
   (opens in 30 s). Maintenance on group `<name>`, with data collection:
   problem suppressed, operations paused, sent ~30 s after it ends; one on
   a discovered host is refused.
3. **step3-dashboard** — host `<name> proxy` (*Zabbix proxy health*,
   monitored by the proxy itself), dashboard `<name> mon`: problems (group;
   node hosts), node CPU, memory, ready, podinfo requests/5xx, p95, proxy
   queue. `lab4/solution/dashboard.json` + `lab0/dashboard` if short of
   time.
4. **step4-drill** — first, the proxy and kube-state-metrics to the
   control plane (`nodeSelector` in `~/m3/values.yaml`): after lab 3 they
   may sit on the worker, and pausing it would blind Zabbix. Then
   predictions, `lab4/break control` (`docker pause` the worker) and
   `lab4/break workload` (load on `/status/500`), `lab4/reset`.

   | Fault | Kubernetes | Zabbix (dry run) |
   | --- | --- | --- |
   | control | `NotReady` 49–50 s | *node not ready* 60–88 s, sent; podinfo silent (dependency); node host: nothing; replicas mismatch Warnings ~5 min; podinfo's *no data* paged 1 s after the node recovered |
   | workload | pods *Running*, *Ready* | *5xx above 1/s* at 101 s; nothing else |
5. **step5-note** — five lines per fault in `~/m3/incidents/`; one change
   applied (dry run: the action's operations from step 2, 2 min steps — a
   1 min problem then sends nothing). Export template and proxy host, the
   dashboard by names, the action as `action.get` JSON (ids: not
   importable); commit, tag `lab4`.

**End state**: the end of the module. `kind delete cluster --name "$CLUSTER"`;
the trainer runs `make zabbix-users-delete` (shared-cluster).

## Size (trainer)

Estimates **(to validate)** on the dry run; module 1 measured a 2-node kind
cluster with Linkerd and Bookinfo at ~3 GiB, this one runs less:

| What | Per trainee | 3 trainees (+ the trainer's demo) |
| --- | --- | --- |
| `mon`: 2 kind nodes, proxy, 2 agents, kube-state-metrics, podinfo, load pod | ~1.5 GiB | ~4.5 GiB (~6 GiB) |
| Zabbix server, web, PostgreSQL (shared) | | ~0.5 GiB measured idle; to measure with 4 proxies and their LLD |

The server side is the unknown: `ZBX_CACHESIZE=256M` and 10 pollers are set
for "a dozen proxies"; lab 2 step 3 (cluster state discovery before the
filter) is the peak — watch *Zabbix server health* during the dry run with 3
trainees and the trainer, and the PostgreSQL volume. Lower the proxies' discovery intervals in
the step files only as much as the room needs.

## Files

```
module3/
  README.md                this file
  versions.env             pinned versions                                written
  Makefile                 catch-up-lab1 … -lab4 (written)
  lab0/                    Makefile: chart, pull, load, credentials, check,
                           pull-consoles; zapi (the API as the trainee),
                           import (host and template exports, see
                           Conventions), render, user-env.jq; depend
                           (trigger dependencies), dashboard (from names) written
  lab1/                    README.md, kind.yaml, step1…5/ (step2-chart/values.yaml,
                           step4-nodes/cut.yaml), solution/               written
  lab2/                    README.md, step1…6/ (step4-churn/), solution/
  lab3/                    README.md, load.yaml, step1…5/ (step1-podinfo/values.yaml),
                           solution/ (templates/: ${UUID:…})              written
  lab4/                    README.md, break (control | workload), reset,
                           step1…5/, solution/ (dashboard.json)           written
../shared-cluster/bin/zabbix   users [--delete], media type Lab webhook   written
```
