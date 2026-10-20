# Lab 1 — Connect a cluster to Zabbix

**Slides:** *Session 1 — Zabbix for Kubernetes* (`zabbix_architecture.md`),
then *Lab 1* (`lab_zabbix_connect.md`) · **~65 min**, then a 10 min debrief

Your cluster `mon-<name>` gets a Zabbix proxy and an agent per node, with the
official Helm chart; the proxy connects to the room's server; then you
monitor the two nodes the way you do it today, as hosts made **by hand**.
Lab 2 replaces those hosts by discovery.

| Step | | ~ |
| --- | --- | --- |
| [step1-cluster](step1-cluster/) | cluster `mon`, Zabbix credentials, `~/m3` | 10 min |
| [step2-chart](step2-chart/) | proxy and agents with the Helm chart | 20 min |
| [step3-proxy](step3-proxy/) | the proxy, seen from the server | 10 min |
| [step4-nodes](step4-nodes/) | the nodes as hosts, by hand | 20 min |
| [step5-export](step5-export/) | export, commit | 5 min |

| File | What it is |
| --- | --- |
| [`kind.yaml`](kind.yaml) | `mon-<name>`: 1 control plane (untainted) + 1 worker |
| [`step2-chart/values.yaml`](step2-chart/values.yaml) | the chart's values, to complete: proxy name, server, PSK, image tags |
| [`step4-nodes/cut.yaml`](step4-nodes/cut.yaml) | a NetworkPolicy that cuts the proxy from the server, and only that |
| [`solution/`](solution/) | `~/m3` at the end of the lab, with `${ZBX_USER}`, `${CLUSTER}`, the node IPs… in place of your values |

**Start**: `make -C lab0 check` green (the trainer ran `make zabbix-users`
and `make -C lab0 pull-consoles`). Everything runs **from `module3/`**:

```sh
cd ~/trainings_exercises/f021bis/module3
source versions.env
source ~/.zabbix/user.env      # once step 1 has written it
```

**End state** (start of lab 2): `mon-<name>` with the chart in namespace
`monitoring`; proxy `<name>` online on the server; hosts
`mon-<name>-control-plane` and `mon-<name>-worker` collecting data, in
group `<name>`; `~/m3` tagged `lab1` with `values.yaml` and `hosts/`.

Catch-up (from `module3/`): `make catch-up-lab1` — recreates nothing that
works: creates `mon` if missing, installs or upgrades the chart with the
solution's values, replaces your hosts on the server by the solution's, and
`~/m3` by the solution (the old one is moved aside).

## Validated on the server

2026-10-20, in `console-jean`, against the room's Zabbix (`make zabbix`,
`make zabbix-users`): every step as written, through the real path (proxy
→ `195.35.2.222:10051` → socat → server) and with `ZBX_API` on the
frontend's Service (the public host name does resolve to `127.0.1.1` in a
console). Measured there: `kind create` 48 s, `lab0 load` 26 s; proxy
online as soon as the pod started; scaled to 0, *offline* by 62 s, back
16 s after; link cut, *offline* after 70 s, back 7 s after, no gap in the
history; Linux template items discovered 27 s after the hosts were made.
New there: both node hosts raise *Linux: Load average is too high (per CPU
load over 1.5 for 5m)* — the server's load, seen through a kind node;
kube-state-metrics runs.

**Found there**: kind's context in a console has no namespace, and
`kubectl` in a pod then falls back to the pod's own namespace, `consoles`
(`kubectl scale deploy/churn` → `namespaces "consoles" not found`). Step 1
and `make mon` set the context's namespace to `default`.

## What was found on a local run

Run end to end on a laptop (2026-10-20), not yet on the server, which was
down: kind v0.33.0, `KIND_NODE`, Helm v4.3.0, Docker 29 with the containerd
image store; the room's server deployed from `../shared-cluster/zabbix/` in
a local kind cluster and the tenant made by `bin/zabbix users`. The proxy
reached the server at the server node's address and NodePort 30051 instead
of `195.35.2.222:10051`, so **the path through the server's `socat` and the
console's dind is not tested**, nor the frontend's Service as `ZBX_API`
from a console.

- **Chart**: `zabbix-helm-chart` 1.3.4, appVersion 7.0.17 (images
  overridden to 7.0.31). The older name `zabbix-helm-chrt` stops at 1.2.4.
  Release `zabbix` gives `zabbix-zabbix-helm-chart-{proxy,agent}`, the
  endpoint names lab 2's templates default to.
- **The proxy's `env` takes literal values only**; the PSK is a file:
  `ZBX_TLSPSKFILE=psk` resolves to `/var/lib/zabbix/enc/psk`, where
  `extraVolumes`/`extraVolumeMounts` (rendered by the chart, not listed in
  its `values.yaml`) mount Secret `zabbix-proxy-psk`. The image writes PSKs
  given as plain values to `enc_internal/`, so the read-only mount is safe.
- **Lists replace lists**: `zabbixProxy.env` in our values replaces the
  chart's whole list; `ZBX_PROXYCONFIGFREQUENCY=10` and the cache size are
  repeated for that reason.
- **`kind load docker-image` fails** with the containerd image store:
  `ctr: content digest sha256:…: not found` (only one platform of a
  multi-platform image is pulled). `lab0 load` saves a single-platform
  archive and uses `kind load image-archive`.
- **Proxy online ~8 s after the pod starts**; the server shows state
  *Online*, version 7.0.31, compatibility *Current*.
- **Traps, as logged** (step 2): `ZBX_TLSCONNECT` left `unencrypted` —
  proxy: `connection of type "unencrypted" is not allowed for proxy "<name>"`;
  a wrong PSK identity — proxy: `TCP successful, cannot establish TLS …
  handshake failure`, server: `cannot find requested PSK identity "…"`.
- **Proxy scaled to 0**: still *Online* at 60 s, *Offline* by 90 s; back
  *Online* 16 s after scaling to 1, with a **new** SQLite database (the chart
  keeps it on an `emptyDir`).
- **Hosts by hand**: an Admin-role tenant can create them (`host.create`
  with `monitored_by: 1`, `proxyid`). First values ~40 s after creation.
  Uptime, memory and CPU count are the machine's running the nodes, exactly
  (`free -b`, `nproc`, `/proc/uptime` there); the host name is the node's.
  `system.sw.packages.get` is *not supported* (`cannot obtain package
  information`). One transient `ZBX_NOTSUPPORTED … agent dropped connection`
  from `zabbix_get`, fine on retry.
- **The agent logs `failed to read request from <node IP>: EOF` every
  10 s**: the kubelet's TCP liveness probe, harmless.
- **kube-state-metrics** crash-looped on the laptop (`failed to create
  fsnotify watcher: too many open files`: `fs.inotify.max_user_instances`
  = 128 there; the server has 8192, `make sysctl`). Not needed in lab 1;
  lab 2 needs it — check it there.
