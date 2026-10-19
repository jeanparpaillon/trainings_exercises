# Module 3 — Monitoring Kubernetes with Zabbix

Exercises for module 3 of **F021bis — Kubernetes in production**. The slides
are in `../../../trainings/f021bis/slides/module3.md`; every lab here names
the slides it belongs to, and the slides point back with
`📖 module3/README.md — Lab N`.

> **Status: specification.** This README describes what each lab must
> contain and check. **Nothing is written or run yet**: no step file, no
> `lab0/`, no trainer script. Facts about the Zabbix Helm chart and the
> Kubernetes templates shipped with 7.0 are from their documentation, not
> from a run, and are marked **(to validate)** where a step depends on them.

| | Lab | Session | ~ |
| --- | --- | --- | --- |
| [lab1/](lab1/) | connect a cluster: proxy and agents with the Helm chart, nodes by hand | 1 | 65 min |
| [lab2/](lab2/) | discover the cluster: Kubernetes templates, LLD, control plane | 2 | 75 min |
| [lab3/](lab3/) | Prometheus metrics in Zabbix: kube-state-metrics, an application, a template | 3 | 65 min |
| [lab4/](lab4/) | alert, dashboard, incident drill | 4 | 55 min |
| [lab0/](lab0/) | chart, images, pair credentials; once before session 1 | — | — |

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

One kind cluster per pair, **`mon`**, in the driver's console, from lab 1 to
lab 4, monitored by the room's Zabbix server through the pair's own proxy:

- **lab 1** creates `mon`, installs the proxy and the agents, and monitors
  the two nodes as hosts created **by hand** — the way they do it today;
- **lab 2** replaces those hosts by **discovery** (nodes, cluster state,
  control plane) and watches objects appear and disappear;
- **lab 3** adds what the templates do not cover: an application's
  `/metrics`, in a template of the pair's own, exported to Git;
- **lab 4** alerts on all of it, builds the cluster dashboard, then one of
  the pair breaks `mon` and the other finds out **from Zabbix only**.

| Cluster | What | Nodes | Used by | Lifetime |
| --- | --- | --- | --- | --- |
| `mon` | kind, `KIND_NODE` | 1 control plane (untainted) + 1 worker | labs 1 → 4 | until the end of the module |

Each lab's end state is the next one's start. A `make catch-up-labN` target
must rebuild it (see [Conventions](#conventions)).

## Where the labs run

| Role | What | Where |
| --- | --- | --- |
| Zabbix server, web UI | one for the room, 7.0 LTS | shared cluster, namespace `zabbix`; UI `https://srv2052563.hstgr.cloud/zabbix/`; trapper `195.35.2.222:10051` (see [`../shared-cluster/README.md`](../shared-cluster/README.md#zabbix)) |
| Zabbix proxy | one per pair, **active**, named after the pair (`pairN`) | a pod in `mon` |
| Zabbix agent 2 | DaemonSet, `hostNetwork`, one per node | `mon` |
| kube-state-metrics | deployed by the chart | `mon` |
| the trainee | web UI as user `pairN`; `kubectl`, `helm`, `curl` in the console | console |

**In pairs, the whole module in the driver's console**, as in module 2:
`mon` carries the four labs. Swap the keyboard, not the console. Lab 4's
drill is the exception: the *other* member breaks the cluster, from the
driver's console, while the driver looks only at the Zabbix UI.

The proxy reaches the server by its **IP**, never the host name (it resolves
to `127.0.1.1` inside every container of the server), and the server only
accepts proxies declared in it: autoregistration is off and port 10051 is
open to the Internet. Hence the per-pair proxy and PSK below.

### The shared server: what each pair gets (trainer)

One Zabbix for the room means every pair sees the same frontend. Each pair
is confined to its own groups, so that nobody edits another pair's hosts or
the global templates:

| Object | Name | Created by |
| --- | --- | --- |
| proxy | `pairN`, active, PSK identity `pairN`, encryption PSK only | trainer (`lab0`) |
| host group | `pairN` | trainer |
| template group | `pairN` | trainer |
| user group | `pairN`: read-write on both groups above, read on `Templates/*` | trainer |
| user | `pairN`, role *Admin* (not *Super admin*), in user group `pairN` | trainer |
| the Kubernetes and Linux templates | as shipped with 7.0 (`Templates/Applications`, `Templates/Operating systems`, …) | imported by the server at first start; linked by the pairs, never edited |

Everything a pair creates — hosts, its lab 3 template (named `pairN
podinfo`), dashboards, actions — goes in its groups. Lab 4's actions are
filtered on host group `pairN`; the step file says why (one server, one
action table: an action without a filter fires for everyone).

**To write**: `../shared-cluster/bin/zabbix pairs`, run on the server like
the other `bin/zabbix` commands, from a pair file `/root/users/pairs.txt`
(`pairN <trainee> <trainee>`), through the JSON-RPC API (`api()` already
there). Re-runnable: creates what is missing, never rotates a PSK or a
password that exists. It stores, for each trainee of the pair, a Secret
`zabbix-pair` in **the trainee's namespace on the shared cluster**:
`name`, `password`, `psk_identity`, `psk`. The console reads it with its
`training-f021bis` context:

```sh
kubectl --context training-f021bis get secret zabbix-pair -o jsonpath='{.data.psk}' | base64 -d
```

`make -C lab0 credentials` turns that into `~/.zabbix/pair.env` (mode 600:
`ZBX_PAIR`, `ZBX_PSK_IDENTITY`, `ZBX_PSK_FILE`, `ZBX_PASSWORD`) and
`~/.zabbix/pair.psk`, outside the repo. Nothing secret goes in Git.

`bin/zabbix pairs --delete` removes the pairs' proxies, hosts, templates
and users at the end of the module (deleting a proxy first deletes nothing
it monitors: hosts first).

## Conventions

- **Run everything from `module3/`**, after `source versions.env` and
  `source ~/.zabbix/pair.env`. Paths in the step files are relative to it.
- **Steps are directories**, `labN/stepM-<name>/README.md`, as in modules 1
  and 2: goal, what to do (UI path or command), what to look for, questions
  to answer before moving on. Given files (Helm values, manifests) sit next
  to the step file.
- **The UI is the tool.** The trainees know the Zabbix frontend; step files
  give the menu path (*Data collection → Hosts*, *Monitoring → Latest
  data*) and the values to enter, not screenshots. Each step names one
  check that does not need the UI (`kubectl`, `zabbix_get` from the proxy
  pod, the API with `curl`) so that a broken UI is not a dead end.
- **Zabbix configuration is code at the end of each lab**: the pair exports
  its hosts and templates as YAML (*Export*, or `configuration.export` with
  `curl`) into `~/m3/`, a Git repo from lab 1 on, tag `lab1`…`lab4`. The
  catch-up targets import those exports back (`configuration.import`); they
  are also the solutions (`labN/solution/`, YAML with `pairN` replaced by
  `${ZBX_PAIR}`, `envsubst` before import).
- **Data takes time.** Zabbix updates are not instant: discovery runs every
  hour by default, items every minute. Step files say which intervals to
  lower for the lab (on the host's macros or with *Execute now*), and how
  long to wait before deciding something is broken. Never wait on a 1 h
  discovery in a lab.
- **Kubernetes side through `kubectl`, Zabbix side through the UI**: when a
  check disagrees, the step file says which one is the truth (the cluster),
  and what lag is normal.
- **Contexts.** kind switches to `kind-mon`; the shared cluster is
  `training-f021bis`, used only to read the pair's Secret. Check
  `kubectl config current-context` before anything destructive.

**Catch-up** (from `module3/`): `make catch-up-lab1`, `-lab2`, `-lab3`
recreate `mon` from nothing (cluster, chart with the pair's PSK, podinfo
from lab 3 on), delete the pair's hosts and templates on the server and
import `labN/solution/` (~5 min, **to measure**). Keep them in sync when an
end state changes.

## Prerequisites

| Tool | Where |
| --- | --- |
| `kubectl`, `kind`, `helm` (v4), `docker`, `curl`, `git` | console image |
| `jq`, `envsubst` | console image **(to check)**; else `lab0` puts `jq` into `~/bin` |
| `zabbix_get` | in the proxy image (`kubectl exec` into the proxy pod) **(to validate)**; not installed in the console |
| Zabbix Helm chart | `lab0 chart`: the `.tgz` at `ZABBIX_CHART_VERSION` into `lab0/charts/`, installed from the file (no network dependency on the day) |
| images | `lab0 pull`: proxy, agent2, kube-state-metrics, podinfo, `KIND_NODE`, into the console's Docker, then `kind load` in lab 1 |

### Versions

All in `versions.env` (to write; same format as modules 1 and 2):

| Variable | Value | Notes |
| --- | --- | --- |
| `KIND_NODE` | module 1's `KIND_NODE_TO` (v1.37.0) | already pulled in every console |
| `ZABBIX_VERSION` | `7.0.31` | **must match the server** (`../shared-cluster/zabbix/kustomization.yaml`): same major for the proxy to be accepted; same tag for the agents, to keep one version in the room |
| `ZABBIX_CHART_VERSION` | TODO | official chart `zabbix-helm-chrt`, repository `https://cdn.zabbix.com/zabbix/integrations/kubernetes-helm/7.0` **(to validate: name, repository, the version that matches 7.0.31's templates)** |
| `KSM_VERSION` | the chart's dependency | kube-state-metrics; note its version, the cluster state template relies on its metric names |
| `PODINFO_CHART_VERSION` | `6.15.0` | module 2's; podinfo exposes Prometheus metrics on `:9898/metrics` |

## Lab 1 — Connect a cluster to Zabbix (session 1)

Slides: *Zabbix for Kubernetes: architecture*, *Lab 1 — Connect a cluster
to Zabbix*. 65 min, then a 10 min debrief.

| | Step | ~ |
| --- | --- | --- |
| 1 | cluster `mon`, pair credentials, `~/m3` | 10 min |
| 2 | proxy and agents with the Helm chart | 20 min |
| 3 | the proxy, seen from the server | 10 min |
| 4 | the nodes as hosts, by hand | 20 min |
| 5 | export, commit | 5 min |

Start: `make -C lab0 check` green (the trainer ran `pull-consoles` and
`bin/zabbix pairs`).

1. **step1-cluster** — given `lab1/kind.yaml` (1 control plane, untainted, +
   1 worker, `KIND_NODE`); `kind create cluster --name mon --config …`;
   `kind load docker-image` the pulled images. `make -C lab0 credentials`;
   check `~/.zabbix/pair.env`, log in to the UI as `pairN`, see the empty
   host group. `~/m3`, `git init`. Question: what can user `pairN` see of
   the other pairs, and why is that enough isolation for a lab and not for
   production (one server, one database, one Admin)?
2. **step2-chart** — given `lab1/step2-chart/values.yaml`, to complete:
   proxy `ZBX_HOSTNAME=$ZBX_PAIR`, `ZBX_SERVER_HOST=195.35.2.222`, active
   mode, PSK from a Secret created from `~/.zabbix/pair.psk`
   (`ZBX_TLSCONNECT=psk`, `ZBX_TLSPSKIDENTITY`, `ZBX_TLSPSKFILE`); image
   tags = `ZABBIX_VERSION`; agent2 `hostNetwork`. `helm install zabbix
   lab0/charts/zabbix-helm-chrt-*.tgz -n monitoring --create-namespace -f …`.
   Check: `kubectl -n monitoring get pods -o wide` (proxy, one agent per
   node, kube-state-metrics), proxy logs.
   **(to validate)**: the chart's value names for the proxy's TLS settings
   and whether it mounts a PSK Secret; if not, an `extraVolumes` in the
   values. Expected traps, to keep in the step file once seen: the host
   name instead of the IP, a PSK identity that does not match, a proxy
   image of another major.
3. **step3-proxy** — *Administration → Proxies*: `pairN` *last seen* a few
   seconds ago, version shown and compatible. Then on purpose: scale the
   proxy to 0 for two minutes and back; what did the server show, what did
   the proxy keep (`ProxyOfflineBuffer`, `ProxyLocalBuffer`)? Question: why
   a proxy per cluster rather than agents talking to the server directly
   (one outbound port, buffering, the server never needs a route into the
   cluster)?
4. **step4-nodes** — create two hosts by hand, `mon-control-plane` and
   `mon-worker`, in group `pairN`, *Monitored by proxy* `pairN`, agent
   interface = the node's `InternalIP` (`kubectl get nodes -o wide`), port
   10050, template *Linux by Zabbix agent*. Wait for data (*Latest data*),
   check one value from the proxy pod: `zabbix_get -s <node IP> -k
   system.uptime`. Compare memory, CPU count and uptime with `free`,
   `nproc` in the console. Questions, for the debrief: whose kernel, memory
   and uptime are these (the server's: a kind node is a container)? On their
   production nodes, what does the agent DaemonSet see that a package on the
   host would not, and the reverse? How would the module 2 role install the
   agent as a package instead?
5. **step5-export** — export the two hosts as YAML into `~/m3/hosts/`,
   commit, tag `lab1`. Question: what in the export depends on this cluster
   (IPs), and would it survive `kind delete`? (No — lab 2's answer.)

**End state** (start of lab 2): `mon` with the chart in `monitoring`; proxy
`pairN` connected; two hand-made node hosts collecting data; `~/m3` tagged
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

The two 7.0 templates the lab uses, as documented **(to validate on the
server: names, macros, host prototypes)**:

| Template | Goes on | Reads | Creates |
| --- | --- | --- | --- |
| *Kubernetes nodes by HTTP* | a host `mon nodes`, no interface, monitored by proxy `pairN` | the API (`/api/v1/nodes`, the agents' Endpoints) | one host per node (host prototypes), linked to *Linux by Zabbix agent*; node conditions, allocatable, pods per node |
| *Kubernetes cluster state by HTTP* | a host `mon state`, same | the API and kube-state-metrics | deployments, daemonsets, pods, PVCs… items by LLD; host prototypes for the API server, controller manager, scheduler and kubelets, with their own templates |

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
2. **step2-nodes** — host `mon nodes` with *Kubernetes nodes by HTTP*.
   Lower the discovery interval (macro or *Execute now*). Watch two hosts
   appear in group `pairN` (the host group the prototype names: set by a
   macro **(to validate)**). Then **disable** lab 1's hand-made hosts.
   Question: lab 1's hosts and these collect the same items; which do you
   keep in production, and what happens to each when a node is replaced?
3. **step3-state** — host `mon state` with *Kubernetes cluster state by
   HTTP*. Look at what it discovered: how many items, per object kind.
   Restrict discovery to the namespaces that matter with the template's
   filter macros (`{$KUBE.LLD.FILTER.NAMESPACE.MATCHES}` or equivalent
   **(to validate)**): `default`, `kube-system`, `podinfo` (lab 3's).
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
   `docker exec mon-control-plane grep bind-address
   /etc/kubernetes/manifests/kube-*.yaml`. Fix: `bind-address=0.0.0.0` in
   the two static pod manifests (`docker exec … sed -i`), the kubelet
   restarts them; data arrives. Question: why is that a security decision
   on a production cluster (metrics port open on the node network; their
   authn/authz), and how would they make it permanent (kubeadm
   `ClusterConfiguration`, Kubespray variables from module 2)? etcd's
   metrics (`127.0.0.1:2381`): mentioned, not done.
6. **step6-export** — export `mon nodes` and `mon state` (with their
   macros, minus the token) into `~/m3/hosts/`, delete the lab 1 exports,
   commit, tag `lab2`.

**End state** (start of lab 3): node hosts, cluster state and control plane
discovered under proxy `pairN`, filtered to three namespaces; lab 1's hosts
disabled; `mon`'s control plane serving metrics on `0.0.0.0`.

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

1. **step1-podinfo** — podinfo with its chart at `PODINFO_CHART_VERSION`,
   namespace `podinfo`, 2 replicas; given `lab3/load.yaml`, a pod running a
   `curl` loop against podinfo, mostly `/`, some `/status/500` and
   `/delay/1` (so that errors and latency exist). Read the raw metrics:
   `kubectl -n podinfo port-forward svc/podinfo 9898` and `curl
   localhost:9898/metrics`. Find the counter of requests by status, the
   latency histogram, the Go runtime metrics. Question: which of these is
   worth an alert, which a graph, which nothing?
2. **step2-items** — host `podinfo` in group `pairN`, monitored by proxy
   `pairN`, no interface. Master item: *HTTP agent* on
   `http://podinfo.podinfo.svc:9898/metrics`, history 0 (keep nothing of
   the raw text), every 30 s. Dependent items with preprocessing
   *Prometheus pattern*: requests per status (`http_requests_total{status="200"}`
   then *Change per second*), errors per second (`status=~"5.."`, sum),
   p95 latency **(to validate: Prometheus pattern cannot compute quantiles
   from buckets — use the histogram's `_sum`/`_count` for a mean instead,
   and say why on the slide)**. Question: one HTTP request feeds N items —
   what does that save compared with N HTTP items, and what breaks when the
   master item fails?
3. **step3-lld** — a discovery rule, dependent on the master item,
   preprocessing *Prometheus to JSON* on `http_requests_total`, LLD macros
   `{#STATUS}` and `{#PATH}` from the labels; item prototypes per status
   and path. Watch new items appear when the load hits a new path. Question:
   which label must never be a discovery key (pod name, request ID: the
   cardinality problem the slides end on)?
4. **step4-template** — move all of it into a template `pairN podinfo`, in
   template group `pairN`, with a macro `{$PODINFO.URL}`; unlink nothing
   by hand: create the template, *link* it to the host, delete the host's
   own items. Point it, with the macro, at the second replica's pod IP
   directly: does the template work for any podinfo? Then do the same for
   one thing the cluster state template does not have, from
   kube-state-metrics (e.g. `kube_deployment_status_replicas_unavailable`
   for the `podinfo` deployment) — the same technique on a metric the
   cluster already exposes. Question: when would they rather use the
   agent2 Prometheus plugin or the kube-state-metrics template items
   already there?
5. **step5-export** — export the template into `~/m3/templates/`, commit,
   tag `lab3`. Question, for the wrap-up of the module: who owns this file
   in their organisation, the application team or the monitoring team, and
   how does it reach the server (by hand, the API, `community.zabbix` from
   module 2)? Optional, if time: import it with `community.zabbix` from the
   module 2 venv **(to decide: whether lab0 installs the collection)**.

**End state** (start of lab 4): podinfo under load in `podinfo`; template
`pairN podinfo` linked to host `podinfo`; `~/m3` tagged `lab3`.

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

1. **step1-triggers** — look first at what the templates already define
   (node not ready, pods not ready, replicas unavailable…) and their
   severities. Add, in `pairN podinfo`: error rate above a threshold for 2
   minutes (`min(…,2m)`, not `last()`), no data from the master item for 3
   minutes. Add a **dependency**: podinfo's triggers depend on the node
   *not ready* trigger. Question: on their cluster, which of the shipped
   triggers would page at night, which should not, and where do they
   change that without editing a shipped template (host-level macros,
   overrides)?
2. **step2-action** — an action on problems of host group `pairN`,
   severity *Average* and above, sending to user `pairN` through media
   type `Lab webhook` **(to decide: what the trainer sets up — a webhook
   to an echo receiver in namespace `zabbix` whose page shows each pair's
   messages, or the frontend's notifications only)**. Then a maintenance
   period on `mon-worker`, 15 min, *with data collection*: what do the
   problems and the action do while it is on? Question: which of module 1's
   and module 2's operations (drain, `upgrade-cluster.yml`) should open a
   maintenance first, and who opens it — a human, or the playbook through
   the API?
3. **step3-dashboard** — a dashboard `pairN mon` (owned by `pairN`):
   problems of group `pairN`, node CPU and memory, pods not ready, podinfo
   requests and errors per second, proxy queue. Question: what is on the
   first screen the on-call opens?
4. **step4-drill** — the driver keeps only the Zabbix UI open; the other
   member runs, in the driver's console, `lab4/break` (to write), which
   applies one scenario chosen at random and prints only its number:
   1. worker gone — `docker pause mon-worker` (never `stop`: module 1);
   2. podinfo `CrashLoopBackOff` — a bad argument in its Deployment;
   3. a rollout stuck — an image tag that does not exist;
   4. errors — the load pod switched to `/status/500` only;
   5. the proxy itself stopped — what does *that* look like?

   `lab4/check N` says whether it is fixed; `lab4/reset` undoes any of them.
   Same script layout as module 1's lab 5 (`scenarios/N.sh` with
   `symptom`, `break_it`, `check_it`, `fix_it`). The driver says which
   problem fired first, finds the cause using Zabbix only, then fixes it
   with `kubectl`; time to detect is written down. Swap and draw again if
   time allows. Scenario 5 is the one to discuss: nothing pages when the
   monitoring is what broke — which trigger catches it (proxy *last seen*,
   on the server's side)?
5. **step5-note** — a five-line incident note in `~/m3/incidents/`
   (detected by, time to detect, cause, fix, what to change in the
   monitoring); apply that change (a trigger, a threshold, a dependency).
   Export template, hosts and dashboard, commit, tag `lab4`.

**End state**: the end of the module. `kind delete cluster --name mon`;
the trainer runs `bin/zabbix pairs --delete`.

## Size (trainer)

Estimates **(to validate)** on the dry run; module 1 measured a 2-node kind
cluster with Linkerd and Bookinfo at ~3 GiB, this one runs less:

| What | Per pair | 4 pairs |
| --- | --- | --- |
| `mon`: 2 kind nodes, proxy, 2 agents, kube-state-metrics, podinfo × 2, load pod | ~1.5 GiB | ~6 GiB |
| Zabbix server, web, PostgreSQL (shared) | | ~0.5 GiB measured idle; to measure with 4 proxies and their LLD |

The server side is the unknown: `ZBX_CACHESIZE=256M` and 10 pollers are set
for "a dozen proxies"; lab 2 step 3 (cluster state discovery before the
filter) is the peak — watch *Zabbix server health* during the dry run with 4
pairs, and the PostgreSQL volume. Lower the proxies' discovery intervals in
the step files only as much as the room needs.

## Files to write

```
module3/
  README.md                this file
  versions.env             pinned versions
  Makefile                 catch-up-lab1, -lab2, -lab3
  lab0/                    Makefile: chart, pull, pull-consoles, credentials, check
  lab1/                    README.md, kind.yaml, step1…5/ (step2-chart/values.yaml), solution/
  lab2/                    README.md, step1…6/ (step4-churn/), solution/
  lab3/                    README.md, load.yaml, step1…5/, solution/
  lab4/                    README.md, break, check, reset, lib.sh, scenarios/1…5.sh,
                           step1…5/, solution/
../shared-cluster/bin/zabbix   new command: pairs [--delete]
```
