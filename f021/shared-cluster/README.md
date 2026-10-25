# The shared cluster

The cluster the room works on during the session: one single-node kind
cluster, `training`, on one server (`srv2052563.hstgr.cloud`), the same
baseline as the f021bis cluster ([`../../f021bis/shared-cluster/`](../../f021bis/shared-cluster/)).
Everything it runs is in this directory, and applied by Flux from this repo.

Trainees are `user1`, `user2`… (`TRAINEES` in [`fleet.env`](fleet.env)):
each person is told which one they are. No file here carries a person's name.

| | |
| --- | --- |
| Web console | `https://srv2052563.hstgr.cloud/<you>/`, login `<you>`, password from the trainer |
| API server | `https://srv2052563.hstgr.cloud:6443` |
| Kubernetes | 1.37 |
| Your namespace | `<you>` (e.g. `user3`): you are `admin` in it, and only in it; you may label it |
| Lab applications | `http://<app>.<you>.195.35.2.222.nip.io/` (plain HTTP) |
| Ingress controller | Traefik, IngressClass `traefik` (the default one) |
| Gateway API | GatewayClass `traefik`, shared Gateway `traefik/traefik-gateway` (HTTP) |
| Storage | `local-path` (`StorageClass` `standard`), RWO only, bound to the node |
| Quota | `trainee` in your namespace: 1 CPU / 2 GiB requested, 4 GiB memory limits, 30 pods, 5 PVCs / 10 GiB; default requests from LimitRange `trainee` |
| Metrics | `kubectl top`, VPA (recommendations only), custom metrics for HPA (`requests_per_second`, Linkerd-meshed pods) |
| Monitoring | Grafana at `https://grafana.srv2052563.hstgr.cloud/` (your console login); Prometheus picks up your ServiceMonitors, PodMonitors and PrometheusRules |
| Headlamp | `https://srv2052563.hstgr.cloud/headlamp/`, token: `kubectl create token headlamp --duration=168h` |

## Connect

**From your web console**: nothing to set up. `kubectl`, `helm`, `flux`,
`git`, `jq` and `curl` are installed, the context `training` points at your
namespace, and `$NS` is set:

```sh
kubectl auth can-i create deployments      # yes
kubectl auth can-i list nodes              # yes (read only)
kubectl auth can-i create namespaces       # no
```

Your home directory is kept across console restarts.

**From your own machine**, with the kubeconfig the trainer gives you
(a client certificate, valid for the week):

```sh
export KUBECONFIG=~/Downloads/<you>.kubeconfig    # or merge it into ~/.kube/config
export NS=<you>
kubectl auth can-i create deployments -n "$NS"    # yes
kubectl version                                   # client within one minor of 1.37
```

Use a `kubectl` from 1.36 to 1.38: older clients work for these labs but warn
about the version skew on every call. `kubectl kustomize` is built in.

Everything else in the labs is `kubectl -n "$NS" ...`, and works the same here
as on kind.

## Reaching your services

Each Ingress gets its own host name, with your namespace in it:

```
http://<app>.<namespace>.195.35.2.222.nip.io/<path>
```

e.g. `http://bookinfo.user3.195.35.2.222.nip.io/productpage`. nip.io is
wildcard DNS: `<anything>.195.35.2.222.nip.io` resolves to `195.35.2.222`,
the server, where Traefik picks your Ingress by host name. The same URL works
with `curl` from your web console and in the browser on your machine. Your
Ingress only needs:

```yaml
spec:
  ingressClassName: traefik
  rules:
    - host: <app>.<namespace>.195.35.2.222.nip.io
      http:
        paths:
          - path: /...
```

Things to know:

- **Always put your namespace in the host name.** Two Ingresses with the
  same host and path fight over the same rule.
- **HTTP only.** Only the trainer's host names (`srv2052563.hstgr.cloud`,
  `grafana.`, `registry.`, `linkerd.`) get a certificate; `*.nip.io` names
  are served on port 80 alone.
- **Not `127.0.0.1.nip.io`** as on kind: from your machine that is your
  machine, and from the web console it is the console pod itself.
- `https://srv2052563.hstgr.cloud/<namespace>/` is your web console. Path
  prefixes under that host are still possible with the `strip-ns-app`
  middleware (see [`traefik-strip-prefix.yaml`](infrastructure/configs/traefik-strip-prefix.yaml)),
  but the application must then use relative links; prefer a host name.
- No Ingress, or something that is not HTTP? `kubectl -n "$NS" port-forward
  svc/<name> <port>` always works from your machine.
- **No NodePort, no LoadBalancer**: the quota forbids both. Nothing outside
  the server could reach them anyway.

### Gateway API

The same host names work with an HTTPRoute instead of an Ingress (module 2
network lab), attached to the shared Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
spec:
  parentRefs:
    - { name: traefik-gateway, namespace: traefik }
  hostnames: ["<app>.<namespace>.195.35.2.222.nip.io"]
  rules:
    - backendRefs:
        - { name: web, port: 80 }
```

`kubectl -n "$NS" get httproute web -o yaml`: `status.parents[].conditions`
says whether the Gateway accepted it. Same rules as for Ingresses: your
namespace in the host, HTTP only.

### With a default-deny NetworkPolicy

Traefik reaches your pods from the `traefik` namespace. Once your namespace
denies ingress by default (module 2 network lab, module 5), allow it back:

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels: { kubernetes.io/metadata.name: traefik }
```

and DNS (`kube-system`, UDP and TCP 53) for egress.

## What the labs need, and what is there

Per lab of the eight-module program (see [`../README.md`](../README.md)).

| Module · lab | Needs | Status |
| --- | --- | --- |
| all | Traefik, IngressClass `traefik`, nip.io host names | installed |
| all | namespace `admin` only (`TRAINEES_CLUSTER_ADMIN=false`), quota `trainee` | installed (tenants) |
| 6 · CI/CD | GHCR reachable from the node, public images (or an `imagePullSecret` per namespace) | nothing to install; **check** pulls from `ghcr.io` |
| 2 · storage, StatefulSet | StorageClass `standard`, PVCs in the quota | installed |
| 2 · network | Gateway `traefik/traefik-gateway`, HTTPRoute rights; Gateway API CRDs at the version of Traefik's `go.mod` (v1.6, for `TLSRoute` v1) | installed (Traefik values, `gatewayapi-rbac.yaml`); **check** `kubectl get gatewayclass traefik`: `ACCEPTED True` |
| 2 · network, 5 · Pod Security / NetworkPolicy | a CNI that enforces NetworkPolicy | kindnet enforces it since kind 0.24: **check** with a default-deny in a test namespace |
| 3 · autoscale | metrics-server, VPA recommender, prometheus-adapter (`requests_per_second`) | installed |
| 3 · autoscale, step "HPA on request rate" | Bookinfo meshed (Linkerd proxies export `request_total`) | Linkerd installed; the step injects the namespace |
| 3 · harden, step "spread and budgets" | several nodes to drain | **single node**: trainer demo on kind |
| 4 · monitoring | kube-prometheus-stack, Grafana logins, ServiceMonitor / PrometheusRule rights | installed |
| 4 · logging | a log stack (Loki + an agent) | **not installed**: `kubectl logs` only, or add it here |
| 4 · troubleshooting | namespace-level faults only (`module4/troubleshoot/`), run with the trainee's rights; scenario 6 needs NetworkPolicy enforcement | nothing to install |
| 5 · least privilege | starting from `trainee` rights | installed |
| 5 · Pod Security | trainees label their own namespace | installed (`trainee-<name>-namespace-labels`) |
| 5 · secrets | SOPS (client side + Flux decryption); ESO / Vault optional | SOPS needs nothing in-cluster beyond Flux; ESO, Vault **not installed** |
| 5 · supply chain (theory) | Kyverno for verify-at-admission | **not installed**: demo only |
| 6 · GitOps | Flux, one tenant per trainee on `$GITHUB_OWNER/f021-<name>` | installed, commented out: enabled per trainee during the lab |
| 6 · GitOps, step "canary" | Flagger + Linkerd or Traefik metrics | **not installed**: demo, or add Flagger here |
| 7 · tenants demo | cluster-admin | trainer |
| 7 · backup demo | Velero + object storage | **not installed**: trainer demo on kind (`f021bis/module1/lab4`) |
| 8 · game day | the module 4 faults, the module 6 pipeline | nothing to install |

No longer needed by any lab: Istio, Chaos Mesh, KEDA, Pyroscope, OpenCost.
Linkerd stays for the request-rate HPA and as a deep dive.

---

## Trainer — layout

```
kind.yaml                  the cluster (make create): API and 80/443 on the server
Makefile                   everything below, from the trainer's machine
fleet.env                  HOST, TRAINEES, GITHUB_OWNER, CONSOLE_IMAGE, FLUX_VERSION, RBAC level
console/                   console image: ttyd, kubectl, helm, flux (make image)
clusters/hstgr/            Flux entry point (bootstrap --path)
  flux-system/             multi-tenancy lockdown patches (+ bootstrap output)
  infrastructure.yaml      gateway-api -> infra-controllers -> infra-configs
  room.yaml                -> room
  tenants.yaml             -> tenants
infrastructure/
  controllers/             HelmReleases + values: Traefik (+ Gateway), Linkerd
                           (crds, control plane, viz), kube-prometheus-stack,
                           Headlamp, metrics-server, VPA, prometheus-adapter
  configs/                 Traefik middlewares and HTTPS redirect, Linkerd
                           dashboard Ingress, Linkerd scrape configs
    rbac/                  trainee RBAC, `trainee` and `admin` levels
room/
  consoles/                web consoles, one per trainee   (generated)
  registry/                image registry (optional, GHCR is the default)
tenants/                   one tenant per trainee          (generated)
templates/                 what bin/render generates from
bin/                       render, gen-secrets, grafana-users, kubeconfigs
secrets/, secrets.yaml     generated values, git-ignored   (bin/gen-secrets)
kubeconfig                 cluster-admin, git-ignored      (make kubeconfig)
```

Generated files are committed: Flux reads them from git, and with generic
trainee names they hold nothing personal. Edit the templates, then
`make render`.

Order of application, each layer waiting for the previous one to be healthy:

```
flux-system ─► gateway-api ─► infra-controllers ─► infra-configs ─┬─► room
                                                                   └─► tenants
```

## Trainer — building it

Needs, on the trainer's machine: `ssh root@srv2052563.hstgr.cloud` working,
`kubectl`, the `flux` CLI (same version as `FLUX_VERSION`), `gh` logged in,
`openssl`, `ssh-keygen`, `htpasswd` (apache2-utils). On the server: Docker,
kind. The f021 session runs on the same server as f021bis, in place of its
cluster: see [Switching from f021bis](#switching-from-f021bis) first.

```sh
make create        # kind cluster `training` on the server
make kubeconfig    # ./kubeconfig, cluster-admin
make image         # console image, built on the server, loaded into kind
make secrets       # secrets.yaml from secrets/ (generated if missing), applied
GITHUB_TOKEN=$(gh auth token) make bootstrap
make watch         # every Kustomization Ready: several minutes (image pulls)
make grafana-users # Grafana logins = console passwords
make kubeconfigs   # secrets/kubeconfigs/<name>.kubeconfig, one per trainee
make check         # consoles answer 401 (basic auth), Grafana 200
```

`make secrets` must run before `make bootstrap`: the Linkerd and Grafana
releases need their Secrets on first install. `make bootstrap` installs the
controllers with the lockdown patches, **commits** `gotk-components.yaml` and
`gotk-sync.yaml` under `clusters/hstgr/flux-system/` on `master` of this repo,
and registers a read-only deploy key on it. Both files must already be on
`master`, if only empty (they are committed so): bootstrap builds that
directory, which lists them, before it writes them.

Console passwords are in `secrets/passwords.txt` (`<name> <password> <url>`,
the format of the f021bis server's `/root/users/consoles.txt`). **Back up
`secrets/`**: it also holds the Linkerd trust anchor and the module 6 deploy
keys registered on GitHub; rebuilding with the same `secrets/` gives back
the same passwords and keys.

Check end to end from a trainee namespace (`user1`, from its console or with
its kubeconfig):

```sh
sed "s/CHANGEME/user1/g" ../module1/lab1/step1-deploy/ingress.yaml.tmpl \
  > ../module1/lab1/step1-deploy/ingress.yaml
kubectl -n user1 apply -k ../module1/lab1/step1-deploy
curl -s -o /dev/null -w '%{http_code}\n' \
  "http://bookinfo.user1.195.35.2.222.nip.io/productpage"         # 200
```

and `linkerd check`, `linkerd viz check` if Linkerd matters for the session.

### Switching from f021bis

Both clusters publish the server's 80/443/6443 ([`kind.yaml`](kind.yaml)),
so the f021bis cluster goes before `make create` (which refuses while
`training-f021bis` exists). From this directory:

```sh
ssh root@srv2052563.hstgr.cloud kind get clusters      # training-f021bis?
make -C ../../f021bis/shared-cluster delete           # its consoles' homes and Docker data go with it
ssh root@srv2052563.hstgr.cloud docker rm -f zabbix-trapper   # f021bis's port 10051 forward
```

Delete it only once nothing on it is needed: every f021bis console home,
trainee kind cluster and Zabbix database goes with it. The rest of what f021bis left on
the server is harmless and stays: `/etc/sysctl.d/99-zz-f021bis-kind.conf`
(raised inotify limits), `/root/f021bis/`, `/root/users/consoles.txt`, the
`f021bis-console` image. f021 does not read the f021bis users file: its
trainees and passwords are `TRAINEES` and `secrets/passwords.txt`.

Going back to f021bis is the reverse: `make delete` here (every PVC goes),
then the f021bis build from `make create`.

## Trainer — day to day

- **More or fewer trainees**: edit `TRAINEES` in `fleet.env`, `make render
  secrets`, commit, push; then `make grafana-users kubeconfigs`. Flux does
  not delete a namespace or a console home dropped from the list (prune
  disabled on them): delete those by hand.
- **Console image change**: edit `console/`, bump `CONSOLE_IMAGE` in
  `fleet.env`, `make image render`, commit, push.
- **Module 6, a trainee's Flux tenant**: create `$GITHUB_OWNER/f021-<name>`
  from the sample app, with the trainee as collaborator; `make deploy-keys
  NAMES=<name>`; uncomment `<name>-flux.yaml` in `tenants/kustomization.yaml`,
  commit, push.
- **Change a chart's values**: edit the values file in
  `infrastructure/controllers/`, commit, push: the ConfigMap name changes
  with its content, which upgrades the release. `flux reconcile kustomization
  infra-controllers --with-source` to not wait.
- **Linkerd issuer** expires one year after it was generated:
  `bin/gen-secrets --renew-issuer`, `make secrets`, then
  `kubectl -n linkerd rollout restart deploy/linkerd-identity`.
- **A new HTTPS host**: an Ingress with
  `traefik.ingress.kubernetes.io/router.entrypoints: websecure`, *and* the host
  in [`infrastructure/configs/traefik-https.yaml`](infrastructure/configs/traefik-https.yaml).
- **Starting over**: `make delete`, then the build above. Every PVC goes with
  the cluster (consoles' homes, Prometheus, Grafana users, acme.json).

## Trainer — how it is put together

### Multi-tenancy lockdown

The Flux controllers run with `--no-cross-namespace-refs`,
`--default-service-account=default` and `--no-remote-bases`
([clusters/hstgr/flux-system/kustomization.yaml](clusters/hstgr/flux-system/kustomization.yaml)).
So every platform Kustomization says `serviceAccountName: kustomize-controller`,
every platform HelmRelease `serviceAccountName: helm-controller`, and they all
live in `flux-system` next to their sources. A trainee's Kustomization runs as
their `flux` ServiceAccount, with `edit` in their namespace only.

### RBAC levels

| Level | What trainees get | Where |
| --- | --- | --- |
| `trainee` | `admin` in their namespace, labels on it, the `trainee` quota; read everything else, Secrets excepted; Gateway API, `linkerd viz tap`, mariadb-operator, VPA and custom-metrics types | `infrastructure/configs/rbac/` (groups), `tenants/<name>.yaml` (per trainee) |
| `admin` | the above + `cluster-admin` | `rbac/trainees-cluster-admin.yaml`, `TRAINEES_CLUSTER_ADMIN=true` in `fleet.env` |

`trainee` is the setting, and what the labs assume: every lab runs in the
trainee's namespace, and what needs more (draining a node, creating tenants,
Velero) is a trainer demo. `admin` lets trainees change anything, Flux
included: during a former session two of them ran `flux bootstrap` on the
cluster, one repointing `flux-system` at their own repo. Use it only to
unblock a session.

Each trainee has three identities, all covered: their kubectl certificate
(`CN=<name>`, `O=trainees`, `make kubeconfigs`), their console's
ServiceAccount `consoles/console-<name>`, and their Headlamp ServiceAccount
`<name>/headlamp`.

### Secrets

Nothing secret is in git. [`bin/gen-secrets`](bin/gen-secrets) writes
`secrets.yaml` (git-ignored) from the values kept in `secrets/` (git-ignored),
generating whatever is missing; `make secrets` applies it. Its header lists
every Secret.

### Consoles

ttyd serving `bash -l`, one Deployment per trainee in `consoles`, behind
basic auth, home on a PVC. The image ([`console/`](console/)) is the f021bis
console without Docker, kind, etcd and ansible: built on the server and loaded
into the kind node by `make image`, never pulled from a registry, so a new
tag (`CONSOLE_IMAGE`) is what rolls the consoles. Its `console-init` writes
the `training` kubectl context from the pod's ServiceAccount token.

### The edge

Traefik is the only HTTP layer on the server: it terminates TLS, gets the
Let's Encrypt certificates (ACME HTTP-01) and routes on the Host header.
Nothing runs in front of it. The kind node's port mapping ([`kind.yaml`](kind.yaml))
is the whole "edge":

```
client ─► 195.35.2.222:80/443        docker DNAT on the host (port mapping of the kind node)
        ─► 172.18.0.2:30080/30443    NodePort of Service traefik (kube-proxy DNAT, policy Local)
        ─► Traefik pod :8000/:8443   TLS + routing                traefik-values.yaml
        ─► backend pod IP            straight from the EndpointSlices, no ClusterIP
```

No proxy, so Traefik sees the real client address (`externalTrafficPolicy:
Local` stops kube-proxy from SNATing it away).

| File | What it is |
| --- | --- |
| [`traefik-values.yaml`](infrastructure/controllers/traefik-values.yaml) | the full Helm values of the `traefik` release: ACME resolver `le`, `web` as default entrypoint, `acme.json` on a PVC, Gateway API provider and the shared Gateway |
| [`traefik-https.yaml`](infrastructure/configs/traefik-https.yaml) | HTTP→HTTPS redirect for the hosts that have a certificate |
| [`traefik-strip-prefix.yaml`](infrastructure/configs/traefik-strip-prefix.yaml) | path-prefix middleware for trainees |

How a route ends up on HTTP or HTTPS:

- **No annotation → HTTP only.** `web` is the default entrypoint, so routers
  that name none attach to port 80 alone. That covers every trainee Ingress
  and HTTPRoute (`*.nip.io`), and is what keeps Traefik from asking Let's
  Encrypt for nip.io names, which share one rate limit with the whole
  internet. Never make `websecure` a default, nor put the certResolver on a
  router that would catch `*.nip.io` names.
- **`traefik.ingress.kubernetes.io/router.entrypoints: websecure` → HTTPS.** TLS
  and the `le` resolver are set on the `websecure` entrypoint itself, so that one
  annotation is enough; Traefik orders the certificate for the Ingress host on
  first sight. The host must also be added to `traefik-https.yaml`, or plain
  HTTP on it gets a 404 instead of a redirect. That annotation is on the
  consoles, Headlamp, Grafana, the registry and the Linkerd dashboard.
- **`websecure` has `readTimeout: 0`**, for large registry pushes (Traefik v3
  defaults to 60 s).

**IPv4 only.** The host names have AAAA records, but the cluster is
single-stack IPv4: kube-proxy programs no IPv6 NodePort, so the port mapping
is bound on `0.0.0.0` only and IPv6 connections to 80/443 are refused.
Browsers fall back to IPv4, and so does Let's Encrypt. Serving IPv6 needs a
dual-stack kind cluster (`networking.ipFamily: dual` in `kind.yaml`), i.e. a
recreate.

### Monitoring

kube-prometheus-stack in `monitoring`. Grafana is at
`https://grafana.srv2052563.hstgr.cloud/`: trainees log in with their console
name and password (`Editor`, `make grafana-users`); the trainer is `admin`,
password in Secret `monitoring/grafana-admin`. Prometheus picks up every
ServiceMonitor, PodMonitor and PrometheusRule in any namespace (no `release`
label needed), Grafana every ConfigMap labelled `grafana_dashboard: "1"`, and
trainees get the `monitoring.coreos.com` types through `admin`/`edit`/`view`.
etcd, scheduler, controller-manager and kube-proxy are not scraped: kind binds
their metrics to 127.0.0.1. Linkerd's metrics are scraped into it too
([`linkerd-scrape.yaml`](infrastructure/configs/linkerd-scrape.yaml)), for
Grafana, PrometheusRules, prometheus-adapter and Flagger.

### Not yet run as a whole

This layout has been assembled from the former session's hand-built cluster
and from the f021bis cluster; it has not been bootstrapped end to end yet.
On the first build, look in particular at: the registry (push and pull with
its htpasswd), the consoles (new image, non-root `ubuntu` user), the shared
Gateway (an HTTPRoute accepted and served), and NetworkPolicy enforcement.
