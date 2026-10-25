# Step 2 — scale, roll out, roll back

**Slide:** Exercise — first deployment, objectives 5–6 · **~15 min**

## 5. Scale, then update the image

Edit `first-deploy/k8s/deployment.yaml`: `replicas: 4`, apply; then image
`nginx:1.30`, apply again. Keep a second terminal on the ReplicaSets:

```sh
kubectl -n "$NS" get rs -l app=web -w
```

```sh
kubectl -n "$NS" apply -f first-deploy/k8s/        # replicas: 4
kubectl -n "$NS" apply -f first-deploy/k8s/        # image: nginx:1.30
kubectl -n "$NS" rollout status  deploy/web
kubectl -n "$NS" rollout history deploy/web
```

Scaling changed the number of pods of the same ReplicaSet. The new image
created a **second** ReplicaSet: the rollout scales it up while the first
one goes down to 0. The old one is kept, empty — that is what makes a
rollback instant.

`kubectl scale` and `kubectl set image` do the same in one command, but
your file would no longer say what runs: the next `apply -f` would put the
old values back. Change the file.

## 6. A tag that does not exist

This one by hand, on purpose:

```sh
kubectl -n "$NS" set image deploy/web nginx=nginx:does-not-exist
kubectl -n "$NS" rollout status deploy/web --timeout=60s   # never completes
kubectl -n "$NS" get rs,pods -l app=web
kubectl -n "$NS" describe pod -l app=web | grep -A3 -i 'failed\|back-off'
```

New pods are stuck in `ErrImagePull` / `ImagePullBackOff`, and the old
ones **keep running**: the rollout only removes an old pod once a new one
is available (`maxUnavailable` 25 % of 4 = 1 pod may go). Check the
application still answers (port-forward or `wget`, as in step 1). Then:

```sh
kubectl -n "$NS" rollout history deploy/web
kubectl -n "$NS" rollout undo deploy/web
kubectl -n "$NS" rollout status deploy/web
kubectl -n "$NS" get rs -l app=web
```

## Questions to answer before moving on

- How many old pods were taken down while the new one could not start, and
  why that number? (`kubectl explain deploy.spec.strategy.rollingUpdate`)
- The broken tag never reached your file. What would the next
  `apply -f first-deploy/k8s/` do? And if it had been in the file?
- `rollout history` lists a `CHANGE-CAUSE` column, empty. How would you
  fill it, and would you rather read the answer in git?

Solution: [`kustomization.yaml`](kustomization.yaml) (the broken tag is
not in it).
