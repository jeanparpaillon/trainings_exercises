# Step 1 — triggers and dependencies

**Slides:** *Triggers that matter on Kubernetes* · **~15 min**

Before adding a trigger, read the ones you already have: three templates
linked in labs 2 and 3, a few hundred triggers. Then add what lab 3's
template lacks, and make podinfo's triggers quiet when the node under it
is the problem.

## What is already there

*Data collection → Hosts*, `<name> mon nodes`, `<name> mon state`, and the
discovered `mon-<name>-worker`, *Triggers*, sorted by severity. Or:

```sh
for h in "$ZBX_USER mon nodes" "$ZBX_USER mon state" "$CLUSTER-worker"; do
  lab0/zapi trigger.get "{\"output\": [\"description\", \"priority\"], \"host\": \"$h\", \"expandDescription\": true}" \
    | jq -r --arg h "$h" '.[] | "\(.priority) \($h): \(.description)"'
done | sed 's/\[[^]]*\]/[…]/g' | sort -u | sort -rn
```

(`priority`: 1 information, 2 warning, 3 average, 4 high, 5 disaster.) On
the dry run, among others:

| Trigger | On | Severity |
| --- | --- | --- |
| *Node […] Conditions: Is not in Ready state* | `<name> mon nodes` (one per node, discovered) | **Warning** |
| *Namespace […] Pod […]: Pod is not healthy* | `<name> mon state` | High |
| *Node […] Namespace […] Pod […] Status: Kubernetes Pod not healthy* | `<name> mon nodes` | High |
| *Pod is crash looping*, *Deployment replicas mismatch*, *ReplicaSet mismatch* | `<name> mon state` | Warning |
| *Livez/Readyz […] is unhealthy* (one per API health check) | `<name> mon state` | Warning |
| *Linux: Zabbix agent is not available* | `mon-<name>-worker` | Average |
| *Linux: High CPU utilization* (`min(…,5m)>90`) | `mon-<name>-worker` | Warning |

A node that is not ready is a **Warning**: an action on *Average and
above* would never send it. Keep that for step 2.

## Three triggers in your template

On `<name> podinfo by HTTP`, first a macro (*Macros*):
`{$PODINFO.ERRORS.MAX}` = `1` — the threshold, so that a host can change
it without touching the template. Then *Triggers → Create trigger*:

| Name | Severity | Expression |
| --- | --- | --- |
| `podinfo: 5xx above {$PODINFO.ERRORS.MAX}/s for 2 min` | High | `min(/<name> podinfo by HTTP/podinfo.errors.rate,2m)>{$PODINFO.ERRORS.MAX}` |
| `podinfo: no data for 3 min` | Average | `nodata(/<name> podinfo by HTTP/podinfo.started,3m)=1` |
| `podinfo: rollout stuck` | Average | `last(/<name> podinfo by HTTP/podinfo.rollout.stuck)=1` |

`min(…,2m)`, not `last()`: every value of the last 2 minutes above the
threshold, so one bad read does not page. Normal traffic is ~0.3 5xx/s,
below 1. *No data* says that `/metrics` cannot be read: every podinfo
item then goes unsupported at once (lab 3 step 2), and no other trigger
says so. It is on `podinfo.started`, **not on the master item**: the
master stores no history, and `nodata()` on it is never evaluated — the
trigger sits in state *unknown* (`item history is disabled`), on the
dry run silently, from the start. Any stored dependent item will do.

## The dependency

podinfo runs on the worker. When the worker is not ready, podinfo is
unreachable too, and its *no data* is noise: the node is the problem.

*Data collection → Hosts*, `<name> podinfo`, *Triggers*, `podinfo: no
data for 3 min` (inherited: its name is prefixed by the template),
*Dependencies* → *Add* → host `<name> mon nodes`, trigger *Node
[mon-<name>-worker] Conditions: Is not in Ready state*. The same for the
two others: a stuck rollout or no 5xx count while the node is gone are
the node's problem too.

Or, for all three at once:

```sh
lab0/depend "$ZBX_USER podinfo" "podinfo: " "$ZBX_USER mon nodes" \
  "Kubernetes nodes: Node [$CLUSTER-worker] Conditions: Is not in Ready state"
```

On the host, not on the template: only this host knows which node its
podinfo runs on — the template is for any podinfo. A trigger can depend
on a trigger of another host, discovered ones included.

Without the UI:

```sh
lab0/zapi trigger.get "{\"output\": [\"description\"], \"host\": \"$ZBX_USER podinfo\", \"selectDependencies\": [\"description\"]}" \
  | jq -r '.[] | "\(.description) <- \(.dependencies | map(.description) | join(", "))"'
```

## Questions

- Which of the shipped triggers above would wake you at night, and should
  they? *Pod is not healthy* is High, *node not ready* a Warning: is that
  the order you want?
- Where do you change that without editing a shipped template? (Its
  thresholds are macros — `{$KUBE.REPLICA.MISMATCH.EVAL_PERIOD}`… — set on
  your host; a severity is not a macro: a trigger of your own, or the
  action's conditions, step 2.)
- The dependency names `mon-<name>-worker`. What happens to it when
  podinfo is rescheduled on another node, or the worker is replaced and
  rediscovered?
