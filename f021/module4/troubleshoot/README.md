# Troubleshooting scenarios

**Slides:** *Troubleshooting*, then *Lab — troubleshooting* · **~60 min**

Faults you did not inject, found with a method — **symptom, scope, layer**
— and the tool of each layer. The patient is your namespace as the
monitoring lab left it (`monitoring/step4-dashboard`): WordPress, MySQL as
a StatefulSet with its data and its exporter, the toolbox, the loadgen,
the Ingress and the HTTPRoute — **and your alerts and dashboard**: keep
Grafana open, and note which alert fired, when, and whether it pointed at
the cause. Every path below is relative to `module4/`.

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
  discussing (1, 5).
- Three scenarios show the **same message** on the blog. That is the
  point: the message says where it hurts, not where it broke.

| Group | # | What you are told | Tools that find it |
| --- | --- | --- | --- |
| Application | 1 | "Error establishing a database connection" since WordPress was restarted this morning | `rollout history`, the Deployment's `env`, the Secret, `kubectl exec` into MySQL with each password |
| Network | 2 | the blog does not answer at all | `curl -I`, `describe ingress`, `describe svc`, `get endpointslices` |
| | 6 | "Error establishing a database connection", and nobody deployed anything | `kubectl exec` + `getent hosts mysql`, the toolbox's `nslookup`, `get networkpolicy` |
| Kubernetes objects | 3 | a new WordPress image is still not live | `rollout status`, `get pods`, `describe pod`, `rollout history` |
| | 4 | the blog keeps going down, the pod keeps restarting | `get pods` (RESTARTS), `describe pod` events, `logs --previous` |
| | 5 | WordPress still runs with its old memory setting | `rollout status`, the **ReplicaSet**'s events, `describe quota` |
| Storage | 7 | "Error establishing a database connection" since MySQL moved to faster storage | `get pods`, `describe pod`, `describe pvc`, `get sc`, then **which** claim |

Fast pairs: 1, 5 and 7 have a second trap in the fix.

## Tools you may not have used yet

```sh
# a shell with network tools next to a container that has none
kubectl -n "$NS" debug -it deploy/wordpress --image=nicolaka/netshoot \
  --target=wordpress -- bash
# the refusals that never reach a pod
kubectl -n "$NS" describe rs -l app=wordpress
kubectl -n "$NS" describe resourcequota trainee
# what changed
kubectl -n "$NS" rollout history deploy/wordpress
kubectl -n "$NS" get events --sort-by=.lastTimestamp
# ask the database itself
kubectl -n "$NS" exec -it mysql-0 -- mysql -uwordpress -p
```

On a local kind cluster instead of the shared one:
`export NIP=127.0.0.1.nip.io` (the host suffix of your Ingresses).

## Debrief

For one scenario per pair: the first symptom, each command and what it
ruled out, the cause, the fix — and the shortest path in hindsight. Then
1, 6 and 7 side by side: one message, three layers. And for each: which of
your alerts fired, how long after the fault, and did any of them point at
the cause? (`MySQLLoginFailures` does for 1; nothing does for 3 and 5 —
the old pod keeps serving.)

## For the trainer

Causes:

1. The Secret's `password` changed, then `rollout restart deploy/wordpress`.
   MySQL still has the old password: it reads `MYSQL_PASSWORD` only when
   it initialises an empty data directory (the module 1 WordPress
   question), and its data is on the claim since module 2. Two fixes: put
   the old password back in the Secret (from the attendee's `db.env`) and
   restart WordPress; or keep the new one and change MySQL's
   (`ALTER USER CURRENT_USER() IDENTIFIED BY '…'`, logged in with the old
   one) — the rotation done right. Second trap: fixing the Secret without
   restarting WordPress changes nothing (env vars are read at start).
2. `wordpress` Service selector `app: word-press`: no endpoints, Traefik
   answers 503 on both host names.
3. Image tag `wordpress:6.80-apache` does not exist: ImagePullBackOff on
   the new pod, the old one keeps serving. Fix: `rollout undo`.
4. Liveness probe on port 8080: the pod serves, then is killed every
   ~30 s, then CrashLoopBackOff. Events say `Liveness probe failed`. Fix:
   remove the probe, or point it at port 80.
5. WordPress memory raised just above what the quota has left: the surge
   pod is refused (ReplicaSet events, `exceeded quota`), and with one
   replica `maxUnavailable` rounds down to 0. Fixes, each a trade-off: a
   value that fits, `maxSurge: 0` / `maxUnavailable: 1` (the old pod goes
   first, then the new one fits — at the cost of a short outage), or ask
   for a bigger quota.
6. NetworkPolicy allowing egress everywhere except `kube-system`: no DNS,
   WordPress cannot resolve `mysql`. Needs NetworkPolicy enforcement by
   the CNI (kindnet does on the shared cluster).
7. StatefulSet `mysql` recreated with claim template `fast` on
   StorageClass `fast` (does not exist): claim `fast-mysql-0` Pending,
   `mysql-0` Pending. Fixing only the class gives an empty volume:
   WordPress redirects to its installer, and `check` refuses it. The fix
   is the original template (`data`, `standard`), i.e. delete and
   re-apply the StatefulSet — `kubectl apply -k monitoring/step4-dashboard`
   keeps the exporter; `module2/storage/step3-statefulset` does not, and
   `MySQLDown` keeps firing on the absent exporter: a fix that drops the
   monitoring — which picks up `data-mysql-0` again; then delete
   `fast-mysql-0`.

`check` loads the blog's home page through the Ingress, from wherever it
runs (the web console): a 200 with WordPress's own content, not its
database error page and not its installer. Scenario 4's `check` waits 45 s
to see whether WordPress still restarts. Scenario 1 keeps the original
password in `troubleshoot/.state/` (git-ignored) so that `reset` can put
both sides back, whichever fix was chosen.

Not verified on the shared cluster yet: the whole set, in particular 1
(that MySQL 8.4 lets the user change its own password) and 5 (the quota
margin is computed at `break` time from the quota's status: run it on a
quiet namespace).
