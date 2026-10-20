# Step 4 — objects come and go

**Slides:** *Discovering Kubernetes: templates and LLD* · **~15 min**

A host by hand lives until someone deletes it. A discovered item lives as
long as the object it describes — plus what the discovery rule keeps.

## What the rules keep

*Data collection → Hosts*, `<name> mon state`, *Discovery*: the rules come
from the template. Look at *Keep lost resources period* and *Disable lost
resources* of *Pod discovery*, *Deployment discovery*, *Node discovery*:

| Rule | Shipped |
| --- | --- |
| pods, deployments, replicasets, daemonsets… | kept **0**: deleted as soon as they are lost, history included |
| nodes, API servers, controller managers, schedulers, kubelets | kept 7 days |

On your host, set *Pod discovery*, *Deployment discovery* and *ReplicaSet
discovery* to keep lost resources **1 h** (the minimum: `0` or at least 1 h)
and to disable them **immediately**. That is a change on the host's copy
of a templated rule, which you may make. Leave `<name> mon nodes` as
shipped, to compare.

## A Deployment

```sh
kubectl apply -f lab2/step4-churn/churn.yaml
kubectl -n default get pods -l app=churn -o wide
```

*Latest data*, filter on `churn`: on a dry run its items were on both
hosts 48 s later — on `<name> mon state` the deployment, its replicaset
and 3 pods (64 items), on `<name> mon nodes` the 3 pods (24).

## Scale to 0, then delete

```sh
kubectl -n default scale deploy/churn --replicas=0
```

Within a minute or two: on `<name> mon nodes` the pods' items are
**gone**; on `<name> mon state` they are **disabled**, marked *not
discovered anymore* (the orange icon in the item list), the deployment's
and replicaset's still collect (0 replicas is a state).

```sh
kubectl delete -f lab2/step4-churn/churn.yaml
```

Then every `churn` item of `<name> mon state` is disabled, to be deleted
an hour later. No problem was raised.

Without the UI — the lost items and when they go:

```sh
lab0/zapi item.get "{\"output\": [\"key_\", \"status\"], \"hostids\": [\"$S\"], \"search\": {\"key_\": \"churn\"},
  \"selectItemDiscovery\": [\"status\", \"ts_delete\"]}" \
  | jq -c --arg now "$(date +%s)" '.[] | {key_, status, lost: .itemDiscovery.status,
      delete_in_min: (((.itemDiscovery.ts_delete|tonumber) - ($now|tonumber)) / 60 | floor)}' | head
```

## Questions

- With pods that live minutes, what should be discovered at all — pods, or
  their controllers? What do the shipped lifetimes say the template's
  authors think?
- The `churn` pods were *Running* and *Ready*: which trigger would have
  fired had they not been? Which one would fire if the Deployment had
  fewer available replicas than desired, and after how long
  (`{$KUBE.REPLICA.MISMATCH.EVAL_PERIOD}`)?
- What is lost with an item, history included, and when does that matter
  (an incident review the next day)?
