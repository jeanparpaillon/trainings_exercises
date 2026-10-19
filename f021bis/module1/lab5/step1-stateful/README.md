# Step 1 — Bookinfo with state

**~10 min**

ratings-v2 reads the ratings from MySQL, on a PersistentVolume. Read
[`mysql.yaml`](mysql.yaml): two of its comments are about things that broke
while this lab was written (the MySQL version, the PV type).

```sh
kubectl apply -k lab5/step1-stateful
kubectl -n bookinfo delete deploy ratings-v1 && kubectl -n bookinfo delete pdb ratings-v1
kubectl -n bookinfo rollout status deploy --timeout=5m
kubectl -n bookinfo get pvc,pods -o wide
kubectl get pv -o custom-columns=NAME:.metadata.name,LOCAL:.spec.local.path,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values
kubectl -n bookinfo exec deploy/mysqldb-v1 -c mysqldb -- sh -c \
  'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" test -e "SELECT * FROM ratings"'
curl -s http://127.0.0.1:30080/productpage | grep -c glyphicon-star   # 9: 5 + 4
```

This is the healthy state `lab5/reset` brings back. Look at it now: it is
what you will compare against.

## Questions

- Which node is MySQL on, and why can it never run on the other one?
- MySQL is one replica with `Recreate`. Why can it not be drain-safe like
  the rest, and what would it take?
