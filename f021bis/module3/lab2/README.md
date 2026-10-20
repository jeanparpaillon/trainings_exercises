# Lab 2 — Discover the cluster

**Slides:** *Discovering Kubernetes: templates and LLD* (`zabbix_discovery.md`),
then *Lab 2* (`lab_zabbix_discover.md`) · **~75 min**

Lab 1's hosts were made by hand and hold the nodes' IPs. Here two parent
hosts with the shipped Kubernetes templates read the cluster through its
API, and **discovery** creates and removes everything else: the nodes, the
control plane components, an item set per pod, deployment, daemonset…

| Step | | ~ |
| --- | --- | --- |
| [step1-token](step1-token/) | token and macros | 10 min |
| [step2-nodes](step2-nodes/) | nodes by discovery | 15 min |
| [step3-state](step3-state/) | cluster state | 15 min |
| [step4-churn](step4-churn/) | objects come and go | 15 min |
| [step5-control-plane](step5-control-plane/) | the control plane | 15 min |
| [step6-export](step6-export/) | export, commit | 5 min |

| File | What it is |
| --- | --- |
| [`step4-churn/churn.yaml`](step4-churn/churn.yaml) | Deployment `churn`, 3 replicas, in `default` |
| [`solution/`](solution/) | `~/m3` at the end of the lab: `values.yaml` (lab 1's), `hosts/` = the two parent hosts, with `${ZBX_USER}` in place of your name |

**Start**: lab 1 done (or `make catch-up-lab1`), from `module3/`:

```sh
cd ~/trainings_exercises/f021bis/module3
source versions.env
source ~/.zabbix/user.env
kubectl config current-context        # kind-mon-<name>
```

**End state** (start of lab 3): hosts `<name> mon nodes` and `<name> mon
state` under proxy `<name>`, filtered to `default`, `kube-system`,
`podinfo`; the node and control plane hosts they discovered, all
collecting; lab 1's hosts deleted; `mon`'s controller manager and scheduler
serving metrics on `0.0.0.0`; `~/m3` tagged `lab2`.

Catch-up (from `module3/`): `make catch-up-lab2` — creates `mon` if
missing, `~/m3` = the solution, the chart, the control plane rebound,
your hosts replaced by the two parent hosts, the token set in their
macros; discovery recreates the rest within a few minutes.

## What was found on a local run

Run on a laptop (2026-10-20) like lab 1 (same caveats: a local copy of
the room's server, not the server), with the 7.0.31 templates:

- **TLS**: the templates verify the API's certificate
  (`{$HTTP.TLS.VERIFY}=full`) and the proxy does not trust the cluster's CA:
  *Get nodes check* says `SSL certificate OpenSSL verify result: unable to
  get local issuer certificate (20)`, and nothing is discovered. The lab
  sets `{$HTTP.TLS.VERIFY}=none` on both parent hosts (discovered hosts
  inherit it); the kubelet, scheduler and controller manager serve
  self-signed certificates anyway.
- **Timings**: nodes discovered 26 s after the macros were right (*Get
  nodes* runs every minute, at second 00); cluster state ~90 s; `churn`
  on both hosts 48 s after `kubectl apply`; controller manager data 45 s
  after the `bind-address` fix.
- **Counts**, unfiltered: `<name> mon nodes` 178 items, `<name> mon state`
  452 (pods 255, readyz 38, livez 36, deployments 33, replicasets 30…).
  Filtered to the three namespaces: 138 and 304. The controller manager
  host alone then has 2008 items (its own discovery over its metrics).
- **A filter applies at the next change of the list**: the discovery
  rules *Discard unchanged with heartbeat 3h*. The state host's applied
  within 2 min; the nodes host's waited for the pod list to change
  (`kubectl -n kube-system rollout restart deploy/coredns`: 52 s).
- **Lost resources**: pods, deployments, replicasets are deleted at once
  when lost (the templates' default); nodes and components kept 7 days.
  The *keep lost resources period* is `0` or **at least 1 h** — the
  spec's 10 min is refused (`value must be one of 0, 3600-788400000`). A
  tenant can change it on the host's inherited rule (API; to check in the
  UI's form).
- **Controller manager and scheduler unreachable** (kubeadm binds them to
  `127.0.0.1`): items without data, **no error, no problem**. Nothing
  fires; only *Latest data* shows it.
- **Discovered hosts** are in `Applications` only, monitored by the
  parent's proxy, with the parent's macros (the token included, shown
  masked).
- **Export**: the token is exported as `type: SECRET_TEXT` without its
  value; the inherited rules' changes (lifetime) are not exported at all.
  The catch-up sets the token again after the import.
- **kube-proxy on the worker crash-looped** on the laptop (`fsnotify
  watcher init: too many open files`, three kind clusters on 128 inotify
  instances), so Service names did not resolve from the proxy (`Resolving
  timed out`). Not expected on the server (8192).
