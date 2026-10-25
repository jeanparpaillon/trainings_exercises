# Module 1 — fundamental concepts and cluster architecture

Exercises for module 1 of **F021**. The slides are in the `trainings` repo,
`f021/slides/pages/module1_fundamentals.md`; every lab here names the slide
it belongs to.

| | Lab | Slides | ~ |
| --- | --- | --- | --- |
| [first-deploy/](first-deploy/) | first deployment: nginx, deploy, expose, self-heal, scale, roll out, roll back, ConfigMap | `section-kubernetes.md` | 45 min |
| [cronjob/](cronjob/) | a Job, a CronJob, a run longer than its schedule | `cron.md` | 15 min |
| [lab1/](lab1/) | deploy Bookinfo, service discovery, round-robin across versions | `microservices_lab1.md` | 40 min |
| [wordpress/](wordpress/) | WordPress + MySQL, then configuration and Secret | `lab_wordpress.md` | 40 min |
| [Makefile](Makefile) | pre-pull the images, for a local kind cluster | — | prep |

What stays for the next modules: **Bookinfo** (`lab1/step3-balancing`) is
the application of modules 2 to 5, and **WordPress**
(`wordpress/step2-config`) continues in the module 2 storage lab. Keep both
running. `first-deploy/` and `cronjob/` can be deleted once done.

## Conventions

- **One namespace per attendee.** No manifest hardcodes a namespace; every
  command is `kubectl -n "$NS" ...`. Set `NS` once and forget it. Every path
  is relative to this directory (`cd module1`).
- **Steps are cumulative kustomize overlays.** `kubectl -n "$NS" apply -k
  lab1/step3-balancing` brings you to the end of step 3 from anywhere,
  including from an empty namespace. In `first-deploy/` you write the
  manifests yourself; the step directories are the solution.
- **Read the diff, not just the file.** Each step directory holds only what it
  changes; `diff <(kubectl kustomize <prev>) <(kubectl kustomize <this>)` is
  the honest answer to "what did this step do?".
- Each step has a `README.md` — the step file — with the commands, what to
  look for, and questions to answer before moving on.
- Anything exposed over HTTP gets a host name with your namespace in it:
  `<app>.<ns>.195.35.2.222.nip.io` on the shared cluster. The Ingress files
  that carry it are rendered from a `.tmpl` and git-ignored.

## Prerequisites

- a namespace on the [shared cluster](../shared-cluster/): from your web
  console nothing to install, `$NS` is already set. From your own machine:
  `kubectl` 1.36–1.38 (kustomize is built in) and the kubeconfig the
  trainer gives you
- or a local `kind` cluster, from the repo root:

  ```sh
  make create     # kind cluster; kind.yaml maps host ports 80/443 into the node
  make ingress    # ingress-nginx controller, listening on those ports
  ```

  then Ingresses with IngressClass `nginx` and hosts
  `<app>.<ns>.127.0.0.1.nip.io`: `lab1/step1-deploy/ingress-kind.yaml.tmpl`
  for Bookinfo; for WordPress, edit those two fields after rendering

## Pre-pull the images

Not needed on the shared cluster: its node pulls from the registries
itself. On kind, the room shares one uplink. Do this before the session:

```sh
make -j4 pull-basics pull-tools pull-bookinfo
make load           # kind only: push them into the cluster's own image store
make check          # what is already local
```

## Former material, not used in this program

Kept from the five-day *advanced* program, for deep dives or a follow-up
training: [`lab2/`](lab2/) (Linkerd install, injection, mTLS, golden
metrics, traffic split, Istio demo), `exerciseA/` (tenants: reused as the
module 7 trainer demo), `exerciseB/` (Linkerd multicluster, empty). The
`emojivoto`, `linkerd` and `istio` targets of the Makefile are for them.
