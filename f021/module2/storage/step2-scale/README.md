# Step 2 — scale both tiers

**Slide:** Lab — storage: scale up · **~15 min**

Three WordPress, two MySQL — same manifests, more replicas.

```sh
kubectl apply -n "$NS" -k storage/step2-scale
kubectl -n "$NS" get pods -l 'app in (mysql,wordpress)' -o wide -w
```

## Observe

- WordPress: three pods `Running`, the site works, reload a few times.
- MySQL: the second pod starts, then fails. Read why:

  ```sh
  kubectl -n "$NS" logs -l app=mysql --prefix | grep -i lock
  ```

  Both pods mount the **same** volume — `ReadWriteOnce` means one *node*,
  not one *pod*, and this cluster has a single node. Two `mysqld` on one
  data directory: the second cannot lock it. On a multi-node cluster the
  second pod would rather stay `ContainerCreating` (`Multi-Attach error`).

## Back to one MySQL

```sh
kubectl -n "$NS" scale deploy/mysql --replicas=1
```

## Questions to answer before moving on

- Why could WordPress scale and MySQL not? Where is WordPress's state?
- Which access mode would have made Kubernetes refuse the second pod
  itself, before MySQL had to?
- Two MySQL replicas, each with its own data: what else would they need to
  be one database?
