# Step 4 — default deny

**Slide:** Lab — network: default deny · **~20 min**

By default every pod accepts traffic from every pod of the cluster — your
neighbour reached your database in step 1. A NetworkPolicy that selects a
pod turns that pod into "deny unless allowed".

## Deny everything

```sh
kubectl -n "$NS" apply -k network/step4-netpol/deny
kubectl -n "$NS" get networkpolicy
```

Then try, and note what fails:

```sh
curl -s -o /dev/null -w '%{http_code}\n' -m 5 \
  http://wordpress.$NS.195.35.2.222.nip.io/
kubectl -n "$NS" exec deploy/toolbox -- nslookup wordpress
kubectl -n "$NS" exec deploy/toolbox -- nc -w 3 mysql 3306
```

## Allow what is needed

```sh
kubectl -n "$NS" apply -k network/step4-netpol/allow
```

Read [`allow/allow.yaml`](allow/allow.yaml): DNS for everyone, WordPress
to MySQL on 3306 (both ends), Traefik to WordPress on 80. The blog answers
again, on both host names. Then:

```sh
kubectl -n "$NS" exec deploy/toolbox -- nslookup mysql        # resolves
kubectl -n "$NS" exec deploy/toolbox -- nc -w 3 mysql 3306    # times out
```

The toolbox may resolve the name, not open the connection: only WordPress
talks to the database now. Ask a neighbour to try your MySQL from their
toolbox (`nc -w 3 mysql.<your-ns> 3306`): it times out too.

## Clean up

```sh
kubectl -n "$NS" delete networkpolicy default-deny allow-dns \
  allow-wordpress-to-mysql allow-mysql-from-wordpress allow-from-traefik
```

The next modules (Prometheus scraping your pods, load tests) assume an
open namespace. Module 5 comes back to NetworkPolicies.

## Questions to answer before moving on

- Without `allow-dns`, which error does `wget http://wordpress` give?
  Why is it not a "connection refused"?
- `allow-wordpress-to-mysql` and `allow-mysql-from-wordpress`: delete
  one of the two. What breaks, and why does a flow need both?
- WordPress itself can no longer reach the internet: what stops working
  in its admin pages (updates, plugins)? How would you allow it, and only
  it?
- A NetworkPolicy is enforced by the CNI, not by Kubernetes. What happens
  on a cluster whose CNI does not implement them?
