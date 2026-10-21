# Step 3 — MySQL as a StatefulSet

**Slide:** Lab — storage: StatefulSet · **~20 min**

A StatefulSet gives each pod a stable name (`mysql-0`, `mysql-1`…) and its
**own** claim, created from `volumeClaimTemplates` and kept across pod
deletions.

`kubectl apply` does not delete what the new manifests no longer contain:
remove the MySQL Deployment and its claim first.

```sh
kubectl -n "$NS" delete deploy/mysql pvc/mysql-data
kubectl apply -n "$NS" -k storage/step3-statefulset
kubectl -n "$NS" get sts,pods,pvc -l app=mysql -w
```

New claim, new database: install WordPress once more and write a post.

## Validate

```sh
kubectl -n "$NS" delete pod mysql-0
kubectl -n "$NS" get pods -l app=mysql -w        # mysql-0 again, same claim
kubectl -n "$NS" exec deploy/wordpress -- getent hosts mysql-0.mysql-headless
```

The post is still there.

## Questions to answer before moving on

- Scale the StatefulSet to 2: which pod appears, with which claim? Does it
  fail like in step 2? Is it a replica of `mysql-0`?
- Scale back to 1: what happens to `data-mysql-1`?
- Running a real replicated MySQL takes more than this: what would an
  operator (MySQL Operator, Percona, CloudNativePG for Postgres) do for you?
