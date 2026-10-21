# Troubleshooting scenarios

**Slides:** *Troubleshooting*, then *Lab — troubleshooting* · **~60 min**

Faults you did not inject, found with a method — **symptom, scope, layer**
— and the tool of each layer. The patient is your namespace as module 3
left it: Bookinfo at `module3/harden/step4-spread`, WordPress back with its
data. Every path below is relative to `module4/`.

```sh
export NS=<your-namespace>
cd module4
troubleshoot/reset        # start from a healthy namespace
troubleshoot/break 1      # inject scenario 1; you are told only the symptom
troubleshoot/check 1      # fixed yet?
```

- **Do not read [`scenarios/`](scenarios/) before you are done** with a
  scenario: the method is the exercise. Read it after, to compare your
  path with the cause.
- One scenario at a time, ~10 min each, **at least one per group**. Stuck
  for more than 10 min: the *Tools* column, then the trainer.
- Fix it the way you would in production — the object, not `reset`.
  `reset` is for starting over.
- For each command you run, write down **what it ruled out**.
- Everything happens in your namespace, with your own rights: no
  scenario needs the platform team, but some fixes are trade-offs worth
  discussing (5).

| Group | # | What you are told | Tools that find it |
| --- | --- | --- | --- |
| Application | 1 | the black stars are gone from the page | which version fails, `logs`, the Deployment's `env` |
| Network | 2 | the page does not answer at all | `describe ingress`, `describe svc`, `get endpointslices` |
| | 6 | every box of the page says its service is unavailable | `kubectl debug` + `nslookup`, `get networkpolicy` |
| Kubernetes objects | 3 | a new version of reviews-v3 is still not live | `rollout status`, `get pods`, `describe pod`, `rollout history` |
| | 4 | the stars come and go, ratings keeps restarting | `get pods` (RESTARTS), `describe pod` events, `logs --previous` |
| | 5 | reviews-v2 still runs with its old memory setting | `rollout status`, the **ReplicaSet**'s events, `describe quota` |
| Storage | 7 | the blog lost its database since MySQL moved to faster storage | `describe pod`, `describe pvc`, `get sc`, then **which** claim |

Fast pairs: 5 and 7 have a second trap in the fix.

## Tools you may not have used yet

```sh
# a shell with network tools next to a container that has none
kubectl -n "$NS" debug -it deploy/productpage-v1 --image=nicolaka/netshoot \
  --target=productpage -- bash
# the refusals that never reach a pod
kubectl -n "$NS" describe rs -l app=reviews
kubectl -n "$NS" describe resourcequota trainee
# what changed
kubectl -n "$NS" rollout history deploy/<name>
kubectl -n "$NS" get events --sort-by=.lastTimestamp
```

On a local kind cluster instead of the shared one:
`export NIP=127.0.0.1.nip.io` (the host suffix of your Ingresses).

## Debrief

For one scenario per pair: the first symptom, each command and what it
ruled out, the cause, the fix — and the shortest path in hindsight.

## For the trainer

Causes:

1. `RATINGS_SERVICE_PORT=9081` on reviews-v2: half of the reviews pods
   cannot reach ratings. Only v2 shows black stars, so "stars gone" is
   one version, not the whole service.
2. `productpage` Service selector `app: product-page`: no endpoints,
   Traefik answers 503.
3. reviews-v3 image tag `1.20.30` does not exist: ImagePullBackOff on the
   new pod, the old one keeps serving. Fix: `rollout undo`.
4. ratings liveness probe on port 9081: the pod is Ready, then killed
   every ~30 s, then CrashLoopBackOff. Events say `Liveness probe failed`.
5. reviews-v2 memory raised just above what the quota has left: the
   surge pod is refused (ReplicaSet events, `exceeded quota`), and with 2
   replicas `maxUnavailable` rounds down to 0. Fixes, each a trade-off:
   free quota (scale WordPress down), `maxSurge: 0` / `maxUnavailable: 1`
   (one replica during the rollout), or ask for a bigger quota. Deleting
   the PDB does nothing: a PDB does not govern rollouts.
6. NetworkPolicy allowing egress everywhere except `kube-system`: no DNS.
   Needs NetworkPolicy enforcement by the CNI (kindnet does it since kind
   0.24: check on the cluster before the session).
7. StatefulSet `mysql` recreated with claim template `fast` on
   StorageClass `fast` (does not exist): claim `fast-mysql-0` Pending,
   `mysql-0` Pending. Fixing only the class gives an empty volume:
   WordPress redirects to its installer, and `check` refuses it. The fix
   is the original template (`data`, `standard`), i.e. delete and
   re-apply the StatefulSet (`module2/storage/step3-statefulset`), which
   picks up `data-mysql-0` again; then delete `fast-mysql-0`.

`check` loads the page through the Ingress, from wherever it runs (the web
console): a 200 is not enough, it also looks for productpage's
"currently unavailable" apologies. Scenario 4's `check` waits 45 s to see
whether ratings still restarts.

Not verified on the shared cluster yet: the whole set, in particular 6
(kindnet enforcement) and 5 (the quota margin depends on how much memory
each attendee gave ratings in module 3; `break` computes it from the
quota's status).
