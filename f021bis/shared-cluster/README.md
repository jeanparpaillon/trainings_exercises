# The f021bis dev cluster

kind cluster `training-f021bis` on `srv2052563.hstgr.cloud`, same layout as
f021's shared cluster (Traefik as the only edge, one namespace and one ttyd
web console per trainee), with two differences:

- **trainees are cluster-admin** (module 1 is cluster administration);
- **each console can run its own kind clusters**: the console pod has a
  privileged `dind` sidecar, so `kind create cluster` works from the console.

| | |
| --- | --- |
| Web console | `https://srv2052563.hstgr.cloud/<name>/`, login `<name>`, password from `/root/users/consoles.txt` |
| Your namespace | `<name>`; you are `cluster-admin` anyway |
| Lab applications | `http://<app>.<name>.195.35.2.222.nip.io/` (plain HTTP, IngressClass `traefik`) |
| Storage | `local-path` (`StorageClass` `standard`) |
| Headlamp | `https://srv2052563.hstgr.cloud/headlamp/`, token from the console: `kubectl -n consoles create token console-$NS --duration=168h` |
| Zabbix (module 3) | web UI `https://srv2052563.hstgr.cloud/zabbix/`; server (proxies, active) `195.35.2.222:10051` |

## In the console

```sh
kubectl get nodes                          # the shared cluster, context training-f021bis
kind create cluster --name lab             # your own cluster, in your console's Docker
kubectl get nodes                          # kind switched the context to kind-lab
kubectl config use-context training-f021bis
```

Multi-node and HA clusters work the same (`kind create cluster --config …`
with several `control-plane` / `worker` nodes); mind the size, see below.
Your home (`/root`) and your Docker data (images, kind nodes) are on volumes:
they survive a console restart, but kind clusters come back stopped —
`docker start $(docker ps -aq)` restarts their nodes.

## Files

| File | What it is |
| --- | --- |
| [`kind.yaml`](kind.yaml) | the cluster: API on `0.0.0.0:6443` with the host name in its SANs, NodePorts 30080/30443 on the server's 80/443 |
| [`traefik-values.yaml`](traefik-values.yaml) | full Helm values of the `traefik` release (TLS, Let's Encrypt) |
| [`headlamp-values.yaml`](headlamp-values.yaml) | full Helm values of the `headlamp` release: `/headlamp/`, login with the console's ServiceAccount token |
| [`base/`](base/) | namespace `consoles`, cluster-admin for trainees, HTTP→HTTPS redirect |
| [`templates/trainee.yaml.tmpl`](templates/trainee.yaml.tmpl) | everything per trainee: namespace, admin RoleBinding, console (ttyd + dind), PVCs, Service, Ingress |
| [`console/`](console/) | console image: ttyd, kubectl, kind, helm, etcdctl/etcdutl, docker CLI, ansible |
| [`bin/render`](bin/render) | `trainees/` from the trainee names (git-ignored) |
| [`bin/secrets`](bin/secrets) | runs on the server: console passwords from `/root/users/consoles.txt` |
| [`zabbix/`](zabbix/) | Zabbix 7.0 LTS for every lab cluster: PostgreSQL, server (+ agent2 sidecar), web, Ingress `/zabbix/` |
| [`bin/zabbix`](bin/zabbix) | runs on the server: Zabbix passwords, the `zabbix-trapper` port forward, Admin's password, module 3's per-trainee tenants |

The passwords never leave the server: `make render` only reads the first
column of `consoles.txt`, `make secrets` runs on the server.

## Trainer — building it

From this directory, with `ssh root@srv2052563.hstgr.cloud` working:

```sh
make sysctl        # inotify limits for the nested kind clusters, once per server
make create        # kind cluster on the server
make kubeconfig    # ./kubeconfig, cluster-admin, git-ignored
make edge          # Traefik
make headlamp      # Headlamp, after edge (Traefik's Middleware CRD)
make image         # console image, built on the server, loaded into kind
make secrets       # console passwords
make apply         # render trainees/ + kubectl apply -k .
make check         # each console answers 401 (basic auth), dind is up
make zabbix        # Zabbix for module 3, see below
```

Day to day:

- **New trainee / new password**: edit `/root/users/consoles.txt` on the
  server (`<name> <password> <url>`), then `make secrets apply`. A changed
  password restarts that console.
- **Console image change**: edit `console/`, bump `CONSOLE_IMAGE` in the
  Makefile, `make image apply`.
- **Trainee removed**: `kubectl apply -k` does not prune; delete their
  objects by hand (`kubectl -n consoles delete all,pvc,ingress,sa,secret -l console=<name>`,
  `kubectl delete ns <name>`).

## Zabbix

One Zabbix for the room (`make zabbix`, namespace `zabbix`): the trainees'
lab clusters each run a Zabbix **proxy** (and agents) that connects to it,
actively. Web UI at `https://srv2052563.hstgr.cloud/zabbix/`, user `Admin`;
the password is generated on the first run and kept in the cluster:

```sh
kubectl --kubeconfig=kubeconfig -n zabbix get secret zabbix-admin -o jsonpath='{.data.password}' | base64 -d
```

From a lab cluster, the server is **`195.35.2.222:10051`** — the IP, not the
host name, which resolves to `127.0.1.1` inside every container on the server
(its `/etc/hosts`). The path is a `socat` container on the server,
`zabbix-trapper`, from `0.0.0.0:10051` to the kind node's NodePort 30051:
kind's port mappings are fixed at creation, and nothing cluster-internal
(Service name, ClusterIP, node address) is reachable from a nested cluster,
whose DNS domain and address ranges are the same as this one's.

`make zabbix` is re-runnable: Secrets are created once (the database keeps
the password it was initialised with), the forward is recreated, the Admin
password is only set while it is still the default. Version bump: the tags
in [`zabbix/kustomization.yaml`](zabbix/kustomization.yaml), then `make
zabbix`; the server upgrades the database schema itself, within a major
version. Proxies in the labs must be the same major version (7.0).

Port 10051 is open to the Internet. The server only accepts data from
proxies and hosts declared in it; keep autoregistration off, or use PSK.

**Module 3 tenants**: `make zabbix-users` (`NAMES="user1 user2"` for some)
creates, for each trainee of `/root/users/consoles.txt`, named after their
console login: a host group and a template group `<name>`, a user group with
write on both, read on the shipped `Templates*` groups and on everyone's
hosts, a user `<name>`
(Admin role) and an active proxy `<name>` that only accepts its PSK
(identity `<name>`). Password and PSK are generated once, kept in Secret
`zabbix/zabbix-user-<name>`, and copied to the trainee's namespace as Secret
`zabbix-user` (`name`, `password`, `psk_identity`, `psk`, `server`, `url`).
Re-runnable; it never rotates a password or a PSK. `make
zabbix-users-delete` removes the trainee's maintenances, actions, dashboards,
maps, hosts and templates, then the above. Tested on a local kind cluster
with these manifests (2026-10-19), not yet on the server. Every trainee
reads every trainee's hosts (their host groups, and `Applications`, where
discovered Kubernetes hosts land), and changes only their own.

## Size and security

- The server has 4 CPUs and 15 GiB. Zabbix takes about 0.5 GiB of it. A kind node takes about 1 CPU at start
  and 1–2 GiB; each console also pulls its own `kindest/node` (~1 GB). Count
  on one or two small clusters per trainee at the same time, not more.
- The `dind` sidecar is privileged, inside a kind node that is itself a
  privileged container: a trainee is root on the server if they want to be.
  That is already true of cluster-admin; do not run this cluster next to
  anything that matters. dockerd listens on a unix socket only (no TCP), so
  one console cannot drive another's Docker.
