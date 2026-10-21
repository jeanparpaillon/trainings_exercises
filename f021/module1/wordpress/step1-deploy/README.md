# Step 1 — deploy WordPress and MySQL

**Slide:** Lab — WordPress: deploy · **~20 min**

Read [`mysql.yaml`](mysql.yaml) and [`wordpress.yaml`](wordpress.yaml) first:
a Deployment and a Service each. WordPress finds MySQL by the Service name
`mysql`, as Bookinfo's services found each other in lab 1.

## Generate your Ingress

```sh
sed "s/CHANGEME/$NS/g" wordpress/step1-deploy/ingress.yaml.tmpl \
  > wordpress/step1-deploy/ingress.yaml
```

## Deploy

```sh
kubectl -n "$NS" apply -k wordpress/step1-deploy
kubectl -n "$NS" get pods -l 'app in (mysql,wordpress)' -w   # both 1/1 Running
kubectl -n "$NS" logs deploy/mysql | tail                    # "ready for connections"
```

## Validate

```sh
kubectl -n "$NS" get ingress wordpress
curl -sI http://wordpress.$NS.195.35.2.222.nip.io/   # 302 to /wp-admin/install.php
```

Open the URL in a browser and run the WordPress installer. Write a post.

No answer? `kubectl -n "$NS" port-forward svc/wordpress 8080:80`, then
`http://localhost:8080`.

## Questions to answer before moving on

- Delete the MySQL pod: `kubectl -n "$NS" delete pod -l app=mysql`. The
  Deployment brings it back — where is your post?
- WordPress started before MySQL was ready. What did it do meanwhile?
- `grep -n password wordpress/step1-deploy/*.yaml`: who can read this
  password today?
