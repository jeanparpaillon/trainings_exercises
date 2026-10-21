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
  - **`sample-app/`** for Helm and CI/CD (modules 1, 6): the Node.js
    server of the DevOps training (`devops/exercises/nodejs_server` in the
    trainings repo), which attendees already containerized and built with
    GitHub Actions. Each attendee works on their own copy (a GitHub repo
    created from it), not on an application of their own
- **GitHub tooling**: GitHub Actions and GHCR for images and charts;
  Xray only as one scanner among others.
- **No service mesh or chaos tooling required.** Linkerd stays on the
  shared cluster, but no lab of the new program depends on it.

## Target layout

| Directory | Module | Labs |
| --- | --- | --- |
| `module1/` | Fundamental concepts and cluster architecture | first deployment · Helm · CronJob · Bookinfo · WordPress |
| `module2/` | Storage and network management | storage and StatefulSet · expose and reach your application |
| `module3/` | Scaling and high availability | measure, right-size, autoscale · harden the application |
| `module4/` | Monitoring, logging and troubleshooting | metrics, dashboards, alerts · troubleshooting scenarios |
| `module5/` | Kubernetes cluster security | least privilege · Pod Security, network policies, secrets |
| `module6/` | Observability, CI/CD and troubleshooting | deploy from CI · GitOps pipeline |
| `module7/` | Best practices for operations and administration | tenants (demo) · backup (demo) · production checklist |
| `module8/` | Hands-on workshops and real-world use cases | game day |
| `sample-app/` | — | the application of the Helm and CI/CD labs, with its plain manifests |

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
| First deployment (nginx: deploy, expose, self-heal, scale, roll out, roll back, ConfigMap) | `section-kubernetes.md` | 🆕 | One step per objective, plus the broken-tag rollout. The `k8s/` folder it produces is the input of the Helm lab |
| Chart the sample app, version, publish, deploy | `helm.md` | 🆕 | Needed: `sample-app/` (copy of `devops/exercises/nodejs_server`) with plain manifests in `k8s/` (Deployment, Service, Ingress, ConfigMap) as the starting point, the expected chart as solution, and the publication target switched to GHCR (OCI) |
| CronJob | `cron.md` | 🆕 | One Job, one CronJob, `create job --from=cronjob/` |
| Deploy Bookinfo, service discovery, round-robin | `microservices_lab1.md` | ✅ | `module1/lab1/` step1–step3 |
| WordPress + MySQL, Secret | `lab_wordpress.md` | ✅ | `module1/wordpress/` step1-deploy, step2-config (Secret from the git-ignored `db.env`) |

### Module 2 — Storage and network management

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Persistent storage, scale-up, StatefulSet | `lab_storage.md` | ✅ | `module2/storage/` step1-pvc, step2-scale, step3-statefulset, on top of `module1/wordpress/step2-config` |
| Expose and reach your application (DNS, headless Service, Ingress, HTTPRoute, break it, default deny) | `lab_network.md` | 🆕 | On WordPress or Bookinfo. Gateway API: check the shared cluster's Traefik serves HTTPRoutes in attendee namespaces (`gatewayapi-rbac.yaml`) |

### Module 3 — Scaling and high availability

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Measure, right-size, autoscale (throttling, OOM, VPA, HPA on CPU and on request rate) | `perf_lab1.md` | ✏️ | Today `module3/README.md` Lab 1, steps written but **no step directories yet**. Check what the shared cluster has: metrics-server, VPA recommender, the Prometheus adapter for the request-rate HPA |
| Harden the application (baseline, probes, graceful shutdown, spread and budgets, timeouts, fallback) | `failure_lab1.md` | ✏️ | `module2/lab1/` step1–step6 and `module2/k6/`. Step 4 drains a node: trainer demo on the shared cluster, or kind. Steps 5–6 optional |

### Module 4 — Monitoring, logging and troubleshooting

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Metrics, dashboards and alerts | `lab_monitoring.md` | 🆕 | kube-prometheus-stack is on the shared cluster (`grafana-users.sh` for logins). Needed: ServiceMonitor or PodMonitor allowed in attendee namespaces, a dashboard JSON, a PrometheusRule. No log stack yet: add Loki, or leave logs to `kubectl logs` |
| Troubleshooting scenarios | `lab_troubleshooting.md` | ✏️ | Port `f021bis/module1/lab5/` (`break` / `check` / `reset`, `scenarios/`), which targets a kind `prod` cluster with `docker exec` on the nodes. Keep the namespace-level scenarios: 3 Service selector, 4 quota blocks a rollout, 5 NetworkPolicy blocks DNS, 7 PVC / node affinity. Drop 2, 6 and 8 (node level) and 1 (mesh). Add a wrong image / pull secret and a failing probe |

### Module 5 — Kubernetes cluster security

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Least privilege for people and pods | `sec_lab1.md` | ✏️ | Today `module4/README.md` Lab 1, **no step directories yet**. Steps 0–1 (a developer identity, lose cluster-admin) need cluster-admin: on the shared cluster, start from the attendee's real `trainee` rights instead. Steps 4–5 (short-lived tokens, escalation hunt) optional |
| Pod Security, network policies, secrets | `sec_lab2.md` | ✏️ | Today `module4/README.md` Lab 2, **no step directories yet**. Part B overlaps `lab_network.md` step 5: keep one. Part C (SOPS / ESO / Vault): check what the shared cluster runs; the Linkerd authorization step is optional |

### Module 6 — Observability, CI/CD and troubleshooting

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Deploy from CI, without GitOps | `k8s_ci.md` | 🆕 | A workflow in `sample-app/`: build, scan (Trivy), push to GHCR, `helm upgrade` with a namespace-scoped kubeconfig |
| GitOps pipeline: config repo, tenant, drift, secrets, pipeline, canary, alerts | `k8s_ci.md`, `gitops_lab.md` | ✏️ | Today `module5/README.md` Lab 1, **no step directories yet**. Rebase on the sample app's chart instead of Bookinfo; Artifactory → GHCR. Flagger needs Linkerd or Traefik metrics: check on the shared cluster, or keep the canary as a demo |
| Troubleshooting a pipeline and a deployment | `ci_troubleshooting.md` | 🆕 | Broken workflows (permissions, GHCR auth), ImagePullBackOff on a private image, failed / pending Helm release, Flux object not Ready |

### Module 7 — Best practices for operations and administration

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Create tenants (trainer demo) | `multi_tenancy.md` | ✏️ | `module1/exerciseA/tenant/` (quota, LimitRange, RBAC, NetworkPolicy). Needs cluster-admin: demo, or compare with the trainees' tenants in [`shared-cluster/tenants/`](shared-cluster/tenants/) |
| Backup and restore (trainer demo) | `backup.md` | ✏️ | Port `f021bis/module1/lab4/` step3-velero and step4-schedule; etcd steps stay in f021bis |
| Production checklist on the sample app and Bookinfo | `prod_checklist.md` | 🆕 | A checklist file to fill in, one line per item, each pointing to its module |

### Module 8 — Hands-on workshops and real-world use cases

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Game day | `failure_game.md` | ✏️ | Today `module2/README.md` Game day, built on Chaos Mesh and the mesh. Rewrite with faults a namespace admin can inject and fix: the troubleshooting scenarios of module 4, plus a bad rollout, quota exhaustion and a missing Secret. Teams fix through the pipeline of module 6 |
| Open questions, architecture review | `use_cases.md` | ✅ | No material: discussion of SGA use cases brought by the attendees, no hands-on on their applications |

## Former material not used in the new program

Kept for deep dives or a follow-up training. Not to be moved into the new
layout.

| Material | Content |
| --- | --- |
| `module1/lab2/` | Linkerd install, injection, mTLS, golden metrics, traffic split, Istio demo |
| `module1/exerciseB/` (empty) | Linkerd multicluster |
| `module2/lab2/`, `module2/faults/` | mesh timeouts, retries, failure accrual; Chaos Mesh pod kill, delay, partition |
| `module3/README.md` Lab 2, Slot 4 | images and startup, network latency; profiling; bottleneck, KEDA, cost |
| `module4/README.md` Slot 4 | audit workshop; red / blue team, policy-as-code, compliance evidence |

## Other updates

- Every module README points to the former slides
  (`../../training_f021/slides/pages/moduleN.md`) and to "day N" of the
  former program: retarget to the new module pages.
- `CLAUDE.md` (training material in `../training_f021`, "Advanced
  Kubernetes"): update the name and path.
