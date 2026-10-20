# Step 4 — a template of your own

**Slides:** *A template of your own, as code* · **~15 min**

What is on `<name> podinfo` works for that host. Moved into a template,
with the URL as a macro, it works for any podinfo — what the application
team would hand over with the application.

## The template

*Data collection → Templates → Create template*:

| Field | Value |
| --- | --- |
| Template name | `<name> podinfo by HTTP` (names are unique on the server, hosts and templates together) |
| Template groups | `<name>`: the one template group you write |
| Macros | `{$PODINFO.URL}` = `http://podinfo.podinfo.svc:9898/metrics` |

## Items in, then link

1. *Data collection → Hosts*, `<name> podinfo`, *Items*: select every
   item (the discovered ones are not needed: the rules recreate them),
   *Copy* → *Templates* → `<name> podinfo by HTTP`. The master must be in
   the selection, or its dependents cannot be copied.
2. On the template, the master item: URL → `{$PODINFO.URL}`.
3. Discovery rules have no *Copy*: create the two of step 3 again on the
   template, **same keys**, with their prototypes.
4. *Data collection → Hosts*, `<name> podinfo`, *Templates*: link `<name>
   podinfo by HTTP`.

Then look at the host's items: each is now prefixed with the template's
name, **and kept its history**. Linking a template whose item has the same
key as an item of the host *adopts* the host's item — same item, now
inherited, the template's settings (the URL is the macro now) — instead
of refusing or duplicating it. The discovery rules too, and their
discovered items. Whatever is left without the prefix was not in the
template (a key typed differently): delete it.

## Any podinfo

On the host, *Macros*, *Inherited and host macros*: change
`{$PODINFO.URL}` to the pod itself, then back:

```sh
kubectl -n podinfo get pods -l app.kubernetes.io/name=podinfo -o wide    # the pod's IP
```

`http://<pod IP>:9898/metrics`: the same values (one pod). The template
does not know or care where podinfo is: another cluster, another
namespace, another proxy, only the macro changes.

## Two replicas

Scale podinfo to two, and leave the URL on the Service:

```sh
kubectl -n podinfo scale deploy/podinfo --replicas=2
```

Two or three minutes later, *Latest data*: `podinfo: started` **changes
at every read**, between two times a few seconds apart, and `requests per
second` drops from ~3.3 to 1.2–2.4, jumping. On the dry run:

```text
started:   …932.44  …932.44  …935.59  …935.59  …935.59  …935.59  …932.44
req/s:     1.80  1.17  1.80  1.63  1.80  2.40
```

The Service sends each read to either pod. Each has its own counters: the
items read one pod's, then the other's, and *Change per second* computes
a rate between two different processes. Nothing is red — the numbers are
just wrong. Back to one:

```sh
kubectl -n podinfo scale deploy/podinfo --replicas=1
```

## One thing the cluster state template does not have

kube-state-metrics publishes a Deployment's conditions; *Kubernetes
cluster state by HTTP* reads its replica counts, not its conditions. A
rollout that cannot finish has `Progressing=False`. Add to the template —
the same technique on a metric the cluster already exposes:

| Macro | Value |
| --- | --- |
| `{$PODINFO.KSM.URL}` | `http://zabbix-kube-state-metrics.monitoring.svc:8080/metrics` |
| `{$PODINFO.NAMESPACE}` | `podinfo` |
| `{$PODINFO.DEPLOYMENT}` | `podinfo` |

| Name | Key | Type | Details |
| --- | --- | --- | --- |
| `podinfo: kube-state-metrics` | `podinfo.ksm.metrics` | *HTTP agent*, text | URL `{$PODINFO.KSM.URL}`, every `1m`, history *Do not store* |
| `podinfo: rollout stuck` | `podinfo.rollout.stuck` | *Dependent*, numeric (unsigned) | *Prometheus pattern* `kube_deployment_status_condition{namespace="{$PODINFO.NAMESPACE}",deployment="{$PODINFO.DEPLOYMENT}",condition="Progressing",status="false"}`, *value* |

`0` within a minute. (The whole cluster's state, ~216 KB, read once a
minute for one number: see the questions.)

If time, a rollout that cannot finish:

```sh
kubectl -n podinfo patch deploy podinfo -p '{"spec": {"progressDeadlineSeconds": 30}}'
kubectl -n podinfo set image deploy/podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.15.0-nope
```

On the dry run: `rollout stuck` = 1 within 50 s. The cluster state
template raised *Pod is not healthy* (High) and *ReplicaSet mismatch*,
both named after the generated pod and ReplicaSet. And podinfo was
**down** the whole time: the chart sets `maxUnavailable: 1`, so with one
replica the old pod goes first — while the Deployment says
`Available=True`. Undo:

```sh
kubectl -n podinfo rollout undo deploy/podinfo
kubectl -n podinfo patch deploy podinfo -p '{"spec": {"progressDeadlineSeconds": 600}}'
```

Without the UI, what the host inherits (`$H` from step 2):

```sh
lab0/zapi item.get "{\"output\": [\"key_\", \"lastvalue\"], \"hostids\": [\"$H\"], \"inherited\": true}" | jq -r '.[] | [.key_, .lastvalue] | @tsv'
```

## Questions

- Does the template work for any podinfo? For a podinfo with two
  replicas? How would you monitor N replicas: one host per pod (discovered
  from kube-state-metrics' `kube_pod_info`, the template on each — and
  new hosts at every rollout), or something that adds the pods' counters
  up before Zabbix reads them (a Prometheus)?
- Reading 216 KB a minute for one number, once per application template:
  when would you rather rely on the items the cluster state template
  already has, or write one kube-state-metrics template of your own, read
  once for every deployment (discovery, as in lab 2)?
- The stuck rollout: which of the three signals would you page on — the
  pod, the ReplicaSet, the rollout? Which one tells the on-call what
  happened?
