# Step 1 — deploy and expose

**Slide:** Exercise — first deployment, objectives 1–4 · **~15 min**

## 1. Write a Deployment and a Service

In `first-deploy/k8s/`, two files:

- `deployment.yaml`: a Deployment `web`, **2 replicas**, one container
  `nginx` from image `nginx:1.29`, port 80, label `app: web`
- `service.yaml`: a Service `web` selecting `app: web`, port 80

Start from the slides (*ReplicaSet and Deployment*, *Service*), or let
kubectl write the skeleton:

```sh
kubectl create deployment web --image=nginx:1.29 --replicas=2 --port=80 \
  --dry-run=client -o yaml > first-deploy/k8s/deployment.yaml
kubectl create service clusterip web --tcp=80:80 \
  --dry-run=client -o yaml > first-deploy/k8s/service.yaml
kubectl explain deployment.spec.selector         # what a field means
```

## 2. Apply, then check

```sh
kubectl -n "$NS" diff  -f first-deploy/k8s/     # what would change
kubectl -n "$NS" apply -f first-deploy/k8s/
kubectl -n "$NS" get deploy,rs,pods,svc -l app=web
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=web
kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail
```

Two pods `Running`, and their two IPs in the EndpointSlice. An empty
EndpointSlice means the Service selector does not match the pod labels.

## 3. Reach it

The Service is `ClusterIP`: only reachable from inside the cluster.
`port-forward` tunnels a local port to it through the API server.

**From your own machine** (with your kubeconfig), then open
`http://localhost:8080` in the browser:

```sh
kubectl -n "$NS" port-forward svc/web 8080:80
```

**From the web console**, where `localhost` is the console pod itself:

```sh
kubectl -n "$NS" port-forward svc/web 8080:80 >/dev/null &
curl -s localhost:8080 | head -5                # "Welcome to nginx!"
kill %1
```

Or from inside the cluster, by the Service name:

```sh
kubectl -n "$NS" run tmp --rm -it --restart=Never --image=busybox:1.37 -- \
  wget -qO- http://web | head -5
```

## 4. Delete a pod

```sh
kubectl -n "$NS" get pods -l app=web -o wide    # note names and IPs
kubectl -n "$NS" delete $(kubectl -n "$NS" get pod -l app=web -o name | head -1)
kubectl -n "$NS" get pods -l app=web -o wide
```

A new pod appears at once, with a new name and a new IP. Nobody restarted
it: the ReplicaSet saw 1 pod where its spec says 2.

## Questions to answer before moving on

- `kubectl -n "$NS" get pod <one-pod> -o yaml`: you wrote no `resources`.
  Where do the ones you see come from? (`kubectl -n "$NS" describe limitrange`)
- The new pod has a new IP. Why does the Service still work?
- What would happen to your pods if you deleted the **ReplicaSet**? And the
  Deployment?

Solution: [`deployment.yaml`](deployment.yaml), [`service.yaml`](service.yaml).
