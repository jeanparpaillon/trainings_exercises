# Exercises for the F021 Kubernetes training

The slides are in the `trainings` repo, `f021/slides/f021.md`: one page per
module (`pages/moduleN_<topic>.md`), each including its sessions and labs.
This repo holds what the labs run.

> **Work in progress.** The training moved from a five-day *advanced* program
> (one day per module: microservices, resilience, performance, security,
> CI/CD) to a broader program in eight modules. The directories below are
> still those of the former program; this README describes the target, and
> for each lab whether its material is **reused as is**, needs an **update**,
> or is **new**.

| | |
| --- | --- |
| [`shared-cluster/`](shared-cluster/) | the session's cluster (kind on one server, platform applied by Flux from this repo): connecting, reaching your services, what each lab needs, how to build it |
| [`module1/`](module1/) … [`module5/`](module5/) | material of the former program, see [Status per module](#status-per-module) |

## Conventions (unchanged)

- **One namespace per attendee**, on the [shared cluster](shared-cluster/) or
  on a local kind cluster. No manifest hardcodes a namespace: every command
  is `kubectl -n "$NS" ...`.
- **Steps are cumulative kustomize overlays**: `kubectl -n "$NS" apply -k
  labN/stepM-...` brings anyone to the end of step M, from an empty
  namespace.
- Each step has a `README.md` with the commands, what to look for, and
  questions to answer before moving on. Each names the slide it belongs to.
- Anything exposed over HTTP works on both clusters: host
  `<app>.<ns>.195.35.2.222.nip.io` on the shared cluster, `.127.0.0.1.nip.io`
  on kind.

## What changes for the labs

- **Attendees are namespace admin, not cluster-admin.** The former labs
  often assumed a kind cluster of one's own (install a controller, drain a
  node, lose cluster-admin, create tenants). In the new program every lab
  must run in one namespace of the shared cluster; what needs more becomes a
  trainer demo.
- **Three applications instead of one.** Bookinfo is no longer the single
  thread of the week:
  - nginx, then **WordPress + MySQL**, for the core objects and storage
    (modules 1–2)
  - **Bookinfo** for microservices, scaling, HA, monitoring, security
    (modules 1, 3, 4, 5)
  - **`sample-app/`** for CI/CD (module 6, Kustomize + Flux, no Helm): the Node.js
    server of the DevOps training (`devops/exercises/nodejs_server` in the
    trainings repo), which attendees already containerized and built with
    GitHub Actions. Each attendee works on their own copy (a GitHub repo
    created from it), not on an application of their own
- **GitHub tooling**: GitHub Actions and GHCR for images;
  Xray only as one scanner among others.
- **No service mesh or chaos tooling required.** Linkerd stays on the
  shared cluster, but no lab of the new program depends on it.

## Target layout

| Directory | Module | Labs |
| --- | --- | --- |
| `module1/` | Fundamental concepts and cluster architecture | first deployment · CronJob · Bookinfo · WordPress |
| `module2/` | Storage and network management | storage and StatefulSet · expose and reach your application |
| `module3/` | Scaling and high availability | measure, right-size, autoscale · harden the application |
| `module4/` | Monitoring, logging and troubleshooting | troubleshooting scenarios (monitoring: trainer demo, no lab) |
| `module5/` | Kubernetes cluster security | least privilege · Pod Security, network policies, secrets |
| `module6/` | Observability, CI/CD and troubleshooting | deploy from CI · GitOps pipeline |
| `module7/` | Best practices for operations and administration | tenants (demo) · backup (demo) · production checklist |
| `module8/` | Hands-on workshops and real-world use cases | game day |
| `sample-app/` | — | the application of the CI/CD labs, with its plain manifests |

Moving the existing material into this layout is the first update:

| Today | Target |
| --- | --- |
| `module1/lab1/` | `module1/` (Bookinfo lab) |
| `module1/exerciseA/` | `module7/` (tenants demo) |
| `module2/lab1/`, `module2/k6/` | `module3/` (harden the application) |
| `module3/` Lab 1 | `module3/` (autoscale) |
| `module4/` Labs 1–2 | `module5/` |
| `module5/` Lab 1 | `module6/` |

## Status per module

Legend: ✅ reuse as is · ✏️ update · 🆕 new

### Module 1 — Fundamental concepts and cluster architecture

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| First deployment (nginx: deploy, expose, self-heal, scale, roll out, roll back, ConfigMap) | `section-kubernetes.md` | ✅ | `module1/first-deploy/` step1-deploy … step3-configmap: attendees write their own `first-deploy/k8s/` (git-ignored), the steps are the solution; the broken-tag rollout is done by hand (`set image`), not in an overlay. The `k8s/` folder it produces is the model for the sample app's Kustomize base (module 6). Server dry-run only so far |
| Jobs and CronJob | `cron.md` | ✅ | `module1/cronjob/` step1-job (a Job that succeeds, one that fails), step2-cronjob (history, `create job --from=cronjob/`), step3-forbid (a run longer than the schedule; Allow / Replace; suspend, clean up). Server dry-run only so far |
| Deploy Bookinfo, service discovery, round-robin | `microservices_lab1.md` | ✅ | `module1/lab1/` step1–step3 |
| WordPress + MySQL, Secret | `lab_wordpress.md` | ✅ | `module1/wordpress/` step1-deploy, step2-config (Secret from the git-ignored `db.env`) |

### Module 2 — Storage and network management

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Persistent storage, scale-up, StatefulSet | `lab_storage.md` | ✅ | `module2/storage/` step1-pvc, step2-scale, step3-statefulset, on top of `module1/wordpress/step2-config` |
| Expose and reach your application (DNS, HTTPRoute, break it, default deny) | `lab_network.md` | ✅ | `module2/network/` step1-dns … step4-netpol, on Bookinfo. Shared Gateway needs the Gateway API CRDs at Traefik's version (v1.6.3: with v1.4 the GatewayClass is never accepted). Still to run end to end: HTTPRoute accepted, default deny enforced by kindnet |

### Module 3 — Scaling and high availability

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Measure, right-size, autoscale (throttling, OOM, VPA, HPA on CPU and on request rate) | `perf_lab1.md` | ✅ | `module3/autoscale/` step1-baseline … step6-hpa-rps and `k6/ramp.yaml`, on module 1 Bookinfo; quota-sized (HPA max 3, WordPress scaled to 0). Checked on the cluster: metrics-server, VPA recommender, `requests_per_second` served and readable by trainees; server dry-run of every step. Not run end to end yet |
| Harden the application (baseline, probes, graceful shutdown, replicas and budgets, timeouts, fallback) | `failure_lab1.md` | ✅ | `module3/harden/` step1-baseline … step6-fallback, on `autoscale/step6-hpa-rps`. Single node: eviction API instead of a drain (drain = trainer demo). Steps 5–6 optional. Fits the quota at ~950m CPU requested during a step 4 rollout; Linkerd native sidecars, so the meshed k6 Job completes. Not run end to end yet |

### Module 4 — Monitoring, logging and troubleshooting

No monitoring lab: the audience is developers, Grafana / Prometheus are shown in a trainer demo (last slide of `monitoring.md`), using Bookinfo from `module3/harden/`.

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Troubleshooting scenarios | `lab_troubleshooting.md` | ✅ | `module4/troubleshoot/` (`break` / `check` / `reset`, `scenarios/1-7`), on the namespace as module 3 left it, attendee's own rights. Ported from `f021bis/module1/lab5/` (namespace-level scenarios; the quota and storage ones reworked), plus a wrong image tag and a failing liveness probe. Not run on the cluster yet |

### Module 5 — Kubernetes cluster security

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Least privilege for people and pods | `sec_lab1.md` | ✏️ | Today `module4/README.md` Lab 1, **no step directories yet**. Steps 0–1 (a developer identity, lose cluster-admin) need cluster-admin: on the shared cluster, start from the attendee's real `trainee` rights instead. Steps 4–5 (short-lived tokens, escalation hunt) optional |
| Pod Security, network policies, secrets | `sec_lab2.md` | ✏️ | Today `module4/README.md` Lab 2, **no step directories yet**. Part B overlaps `lab_network.md` step 5: keep one. Part C (SOPS / ESO / Vault): check what the shared cluster runs; the Linkerd authorization step is optional |

### Module 6 — Observability, CI/CD and troubleshooting

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Deploy from CI, without GitOps | `k8s_ci.md` | 🆕 | A workflow in `sample-app/`: build, scan (Trivy), push to GHCR, `kubectl apply -k envs/dev` with a namespace-scoped kubeconfig. Needed: `sample-app/` (copy of `devops/exercises/nodejs_server`) with plain manifests in `k8s/` (Deployment, Service, Ingress, ConfigMap) as the starting point, and `k8s/` split into `k8s/base/` + `envs/dev/` overlay as the solution |
| GitOps pipeline: config repo, tenant, drift, secrets, pipeline, canary, alerts | `k8s_ci.md`, `gitops_lab.md` | ✏️ | Today `module5/README.md` Lab 1, **no step directories yet**. Rebase on the sample app's Kustomize base and overlays instead of Bookinfo (Flux Kustomization per env, no HelmRelease); Artifactory → GHCR. Flagger needs Linkerd or Traefik metrics: check on the shared cluster, or keep the canary as a demo |
| Troubleshooting a pipeline and a deployment | `ci_troubleshooting.md` | 🆕 | Broken workflows (permissions, GHCR auth), ImagePullBackOff on a private image, broken overlay (`kubectl kustomize` error), Flux Kustomization not Ready |

### Module 7 — Best practices for operations and administration

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Create tenants (trainer demo) | `multi_tenancy.md` | ✏️ | `module1/exerciseA/tenant/` (quota, LimitRange, RBAC, NetworkPolicy). Needs cluster-admin: demo, or compare with the trainees' tenants in [`shared-cluster/tenants/`](shared-cluster/tenants/) |
| Backup and restore (trainer demo) | `backup.md` | ✏️ | Port `f021bis/module1/lab4/` step3-velero and step4-schedule; etcd steps stay in f021bis |
| Production checklist on the sample app and Bookinfo | `prod_checklist.md` | 🆕 | A checklist file to fill in, one line per item, each pointing to its module |

### Module 8 — Hands-on workshops and real-world use cases

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Game day | `failure_game.md` | ✏️ | Today `module2/former-day2.md` Game day, built on Chaos Mesh and the mesh. Rewrite with faults a namespace admin can inject and fix: the troubleshooting scenarios of module 4, plus a bad rollout, quota exhaustion and a missing Secret. Teams fix through the pipeline of module 6 |
| Open questions, architecture review | `use_cases.md` | ✅ | No material: discussion of SGA use cases brought by the attendees, no hands-on on their applications |

## Former material not used in the new program

Kept for deep dives or a follow-up training. Not to be moved into the new
layout.

| Material | Content |
| --- | --- |
| `module1/lab2/` | Linkerd install, injection, mTLS, golden metrics, traffic split, Istio demo |
| `module1/exerciseB/` (empty) | Linkerd multicluster |
| `module2/lab2/`, `module2/former-day2.md`, `module2/kind.yaml` | mesh timeouts, retries, failure accrual; Chaos Mesh pod kill, delay, partition |
| `module3/README.md` Lab 2, Slot 4 | images and startup, network latency; profiling; bottleneck, KEDA, cost |
| `module4/README.md` Slot 4 | audit workshop; red / blue team, policy-as-code, compliance evidence |

## Other updates

- Every module README points to the former slides
  (`../../training_f021/slides/pages/moduleN.md`) and to "day N" of the
  former program: retarget to the new module pages.
- `CLAUDE.md` (training material in `../training_f021`, "Advanced
  Kubernetes"): update the name and path.
