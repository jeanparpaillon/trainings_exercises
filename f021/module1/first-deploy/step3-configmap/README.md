# Step 3 — a ConfigMap as a file

**Slide:** Exercise — first deployment, objective 7 · **~15 min**

nginx serves `/usr/share/nginx/html/index.html` from its image. Replace it
with a page of your own, kept in a ConfigMap.

## 7. Write the ConfigMap, mount it

In `first-deploy/k8s/`:

- `configmap.yaml`: a ConfigMap `web-content` with one key, `index.html`,
  holding a small HTML page
- in `deployment.yaml`: a `volumes` entry of type `configMap`, and a
  `volumeMounts` on the `nginx` container at `/usr/share/nginx/html`,
  read-only (slide *ConfigMap and Secret*)

```sh
kubectl -n "$NS" apply -f first-deploy/k8s/
kubectl -n "$NS" rollout status deploy/web
kubectl -n "$NS" exec deploy/web -- ls -l /usr/share/nginx/html
```

Then reach it as in step 1: your page instead of "Welcome to nginx!".

## Change it without a restart

Edit the HTML in `configmap.yaml`, apply, and fetch the page every few
seconds:

```sh
kubectl -n "$NS" apply -f first-deploy/k8s/
kubectl -n "$NS" get pods -l app=web           # same pods, same AGE
kubectl -n "$NS" exec deploy/web -- cat /usr/share/nginx/html/index.html
```

Within a minute or so, the file changes inside the running pods: the
kubelet refreshes mounted ConfigMaps. No rollout happened.

## Questions to answer before moving on

- `ls -l` showed `index.html` as a symbolic link. What does that let the
  kubelet do when the ConfigMap changes?
- The same value as an environment variable (`env` / `envFrom`): would the
  change reach the running pods? What would it take?
- `50x.html` from the image is gone. Why? (Hint: what does a volume mounted
  on a directory do to what was there; and what is `subPath` for?)
- `rollout history deploy/web`: how many revisions now, and which change
  made a new one?

Solution: [`configmap.yaml`](configmap.yaml), [`kustomization.yaml`](kustomization.yaml).
