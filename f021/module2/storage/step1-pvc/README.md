# Step 1 — a claim for MySQL

**Slide:** Lab — storage: a claim for MySQL · **~20 min**

In module 1, MySQL wrote to an `emptyDir`: every new pod started an empty
database. This step gives it a PersistentVolumeClaim; the StorageClass
`standard` provisions the volume.

```sh
kubectl get storageclass                           # standard (default)
kubectl diff  -n "$NS" -k storage/step1-pvc
kubectl apply -n "$NS" -k storage/step1-pvc
kubectl -n "$NS" get pvc mysql-data -w             # Pending, then Bound
```

`Pending` until the MySQL pod is scheduled: the class binds
`WaitForFirstConsumer`, so the volume is created on the node the pod lands
on.

The pod is new, the volume is empty: MySQL initialises once more. Run the
WordPress installer again and write a post.

## Validate

```sh
kubectl -n "$NS" get pvc,pv                         # the PV was created for you
kubectl -n "$NS" delete pod -l app=mysql
kubectl -n "$NS" get pods -l app=mysql -w
```

Reload the site: the post is still there.

## Questions to answer before moving on

- You never wrote a PersistentVolume. Who did, and from what?
- `kubectl -n "$NS" get pv -o wide`: what is the reclaim policy? What
  happens to the data if you delete the claim?
- Why `strategy: Recreate` on the MySQL Deployment?
