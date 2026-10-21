# Step 2 — configuration and secret

**Slide:** Lab — WordPress: configuration and secret · **~20 min**

Step 1 wrote the database settings twice (once per Deployment) and the
password in clear, in a tracked file. This step moves them out:

- what is not secret (host, database, user) → a ConfigMap, in git
- the password → a Secret, created from a **git-ignored** file

## Create the Secret

```sh
cp wordpress/step2-config/db.env.example wordpress/step2-config/db.env
$EDITOR wordpress/step2-config/db.env          # choose a password
git status --short                             # db.env must NOT appear

kubectl -n "$NS" create secret generic wordpress-db \
  --from-env-file=wordpress/step2-config/db.env \
  --dry-run=client -o yaml \
  | kubectl -n "$NS" apply --server-side -f -
```

Not with `--from-literal=password=...`: that lands in your shell history.

## Apply

```sh
kubectl diff -n "$NS" -k wordpress/step2-config   # what changes
kubectl -n "$NS" apply -k wordpress/step2-config
kubectl -n "$NS" get pods -w
```

Both pods are replaced: their template changed. MySQL starts on a fresh
`emptyDir`, so it initialises again with the new password — and the post
of step 1 is gone (module 2 fixes that).

## Validate

```sh
kubectl -n "$NS" get configmap,secret wordpress-db
kubectl -n "$NS" get secret wordpress-db -o jsonpath='{.data.password}' | base64 -d
kubectl -n "$NS" exec deploy/wordpress -- env | grep WORDPRESS_DB
```

The site answers again on the same URL.

## Questions to answer before moving on

- Base64 is not encryption: who can read the Secret in your namespace?
- Change the password in `db.env` and re-create the Secret. Does WordPress
  see it? What does it take (`kubectl rollout restart`)?
- MySQL only reads `MYSQL_PASSWORD` when it initialises an empty data
  directory. Today that is every restart (`emptyDir`); with the persistent
  volume of module 2, what would changing the Secret do?
