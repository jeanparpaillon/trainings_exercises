# Module 2 — storage and network management

Exercises for module 2 of **F021**. The slides are in the `trainings` repo,
`f021/slides/pages/module2_storage_network.md`; every step here names the
slide it belongs to.

| | Lab | Slides | Starts from | ~ |
| --- | --- | --- | --- | --- |
| [storage/](storage/) | a claim for MySQL, scale both tiers, MySQL as a StatefulSet | `lab_storage.md` | `module1/wordpress/step2-config` | 55 min |
| [network/](network/) | names from the inside, an HTTPRoute, break it, default deny | `lab_network.md` | `module1/lab1/step3-balancing` | 70 min |

Same conventions as module 1: one namespace per attendee, every command
`kubectl -n "$NS" ...`, steps are cumulative kustomize overlays (here on
top of module 1's), and every path is relative to this directory:

```sh
export NS=<your-namespace>
cd module2
```

## Starting state

Both module 1 applications, as module 1 left them:

```sh
kubectl -n "$NS" get secret wordpress-db        # module 1 WordPress, step 2
kubectl -n "$NS" get ingress bookinfo wordpress # your rendered Ingresses
kubectl -n "$NS" get pods                       # Bookinfo + WordPress Running
```

Missing something? The Secret is created by hand (module 1
`wordpress/step2-config/README.md`), the Ingresses are rendered from their
`.tmpl`; then each lab's first step re-applies everything below it.

## End state — what module 3 expects

```sh
kubectl -n "$NS" apply -k network/step2-gateway        # Bookinfo + its HTTPRoute
kubectl -n "$NS" apply -k storage/step3-statefulset    # WordPress, MySQL as a StatefulSet
kubectl -n "$NS" get networkpolicy                     # must be empty
kubectl -n "$NS" delete pvc data-mysql-1 --ignore-not-found
```

- **No NetworkPolicy left** (network step 4 ends with the clean-up): the
  load tests of module 3 and Prometheus scraping in module 4 would be
  blocked. Module 5 comes back to them properly.
- `data-mysql-0` Bound and holding the blog: module 4's storage scenario
  and module 7's backup demo use it.

## On the shared cluster

What the two labs rely on, to check before the session (trainer):

```sh
kubectl get storageclass standard                       # local-path, WaitForFirstConsumer
kubectl get gatewayclass traefik                        # ACCEPTED True
kubectl -n traefik get gateway traefik-gateway          # PROGRAMMED True
```

- **One node, RWO volumes**: the second MySQL of `storage/step2-scale`
  mounts the same volume and fails on the file lock, instead of the
  Multi-Attach error a multi-node cluster gives. The step says so.
- **Gateway API**: the CRDs must be at the version Traefik is built
  against (`shared-cluster/clusters/hstgr/infrastructure.yaml`), or the
  GatewayClass is never accepted and every HTTPRoute is silently ignored.
- **NetworkPolicy** is enforced by kindnet. If `network/step4-netpol/deny`
  blocks nothing, the CNI does not enforce: say so and go on, module 5
  needs it too.

On a local kind cluster: host `<app>.<ns>.127.0.0.1.nip.io` instead of
`195.35.2.222.nip.io`, and a Gateway of your own — the shared one is
Traefik's (see `shared-cluster/infrastructure/controllers/traefik-values.yaml`).

## Former material

[`former-day2.md`](former-day2.md), [`lab2/`](lab2/) and
[`kind.yaml`](kind.yaml) (three workers with zone labels) are the former
day 2, chaos engineering and resilience, not used in this program.
`kind.yaml` still serves the trainer's drain demo of module 3
(`harden/step4-spread`).
