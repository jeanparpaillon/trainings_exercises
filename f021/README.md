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
  - **WordPress** again for CI/CD (module 6, Kustomize + Flux, no Helm), in
    two environments: each attendee works on their own config repo
    (`$GITHUB_OWNER/f021-<name>`, created by the trainer from
    `module6/repo/`), not on an application of their own
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
| `module6/` | Observability, CI/CD and troubleshooting | one 4 h GitOps lab: deploy from CI, then Flux, drift, pipeline, promotion, alerts — WordPress, dev and prod |
| `module7/` | Best practices for operations and administration | tenants (demo) · backup (demo) · production checklist |
| `module8/` | Hands-on workshops and real-world use cases | game day |

Moving the existing material into this layout is the first update:

| Today | Target |
| --- | --- |
| `module1/lab1/` | `module1/` (Bookinfo lab) |
| `module1/exerciseA/` | `module7/` (tenants demo) |
| `module2/lab1/`, `module2/k6/` | `module3/` (harden the application) |
| `module3/` Lab 1 | `module3/` (autoscale) |
| `module4/` Labs 1–2 | `module5/` |

## Status per module

Legend: ✅ reuse as is · ✏️ update · 🆕 new

### Module 1 — Fundamental concepts and cluster architecture

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| First deployment (nginx: deploy, expose, self-heal, scale, roll out, roll back, ConfigMap) | `section-kubernetes.md` | ✅ | `module1/first-deploy/` step1-deploy … step3-configmap: attendees write their own `first-deploy/k8s/` (git-ignored), the steps are the solution; the broken-tag rollout is done by hand (`set image`), not in an overlay. The `k8s/` folder it produces is the model for the WordPress Kustomize base (module 6). Server dry-run only so far |
| Jobs and CronJob | `cron.md` | ✅ | `module1/cronjob/` step1-job (a Job that succeeds, one that fails), step2-cronjob (history, `create job --from=cronjob/`), step3-forbid (a run longer than the schedule; Allow / Replace; suspend, clean up). Server dry-run only so far |
| Deploy Bookinfo, service discovery, round-robin | `microservices_lab1.md` | ✅ | `module1/lab1/` step1–step3 |
| WordPress + MySQL, Secret | `lab_wordpress.md` | ✅ | `module1/wordpress/` step1-deploy, step2-config (Secret from the git-ignored `db.env`) |

### Module 2 — Storage and network management

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Persistent storage, scale-up, StatefulSet | `lab_storage.md` | ✅ | `module2/storage/` step1-pvc, step2-scale, step3-statefulset, on top of `module1/wordpress/step2-config` |
| Expose and reach your application (DNS, HTTPRoute, break it, default deny) | `lab_network.md` | ✅ | `module2/network/` step1-dns … step4-netpol, on WordPress (`storage/step3-statefulset` + a busybox toolbox); allow policies scoped to WordPress → MySQL and Traefik → WordPress. Shared Gateway needs the Gateway API CRDs at Traefik's version (v1.6.3: with v1.4 the GatewayClass is never accepted). Still to run end to end: HTTPRoute accepted, default deny enforced by kindnet |

### Module 3 — Scaling and high availability

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Measure, right-size, autoscale (throttling, OOM, VPA, HPA on CPU and on request rate) | `perf_lab1.md` | ✅ | `module3/autoscale/` step1-baseline … step6-hpa-rps and `k6/ramp.yaml`, on module 1 Bookinfo; quota-sized (HPA max 3, WordPress scaled to 0). Checked on the cluster: metrics-server, VPA recommender, `requests_per_second` served and readable by trainees; server dry-run of every step. Not run end to end yet |
| Harden the application (baseline, probes, graceful shutdown, replicas and budgets, timeouts, fallback) | `failure_lab1.md` | ✅ | `module3/harden/` step1-baseline … step6-fallback, on `autoscale/step6-hpa-rps`. Single node: eviction API instead of a drain (drain = trainer demo). Steps 5–6 optional. Fits the quota at ~950m CPU requested during a step 4 rollout; Linkerd native sidecars, so the meshed k6 Job completes. Not run end to end yet |

### Module 4 — Monitoring, logging and troubleshooting


| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Monitoring your application (look, exporter and edge metrics, alerts, dashboard as code) | `lab_monitoring.md` | 🆕 | `module4/monitoring/` step1-look … step4-dashboard, on WordPress (`module2/network/step2-gateway`): loadgen through Traefik, mysqld-exporter sidecar + PodMonitor, PrometheusRule and dashboard ConfigMap rendered per namespace. Needs the platform PodMonitor `traefik/traefik` for the edge metrics. Exporter checked locally (Docker); manifests and PromQL checked on the cluster (dry-run, queries); not run end to end yet |
| Troubleshooting scenarios | `lab_troubleshooting.md` | ✅ | `module4/troubleshoot/` (`break` / `check` / `reset`, `scenarios/1-7`), on WordPress as module 2 left it (`network/step2-gateway`), attendee's own rights. Ported from Bookinfo: 1 password rotated in the Secret only, 2 Service selector, 3 missing image tag, 4 liveness probe, 5 quota-stuck rollout, 6 DNS blocked by a NetworkPolicy, 7 StatefulSet on a missing StorageClass. Patches pass a server dry-run; not run end to end yet |

### Module 5 — Kubernetes cluster security

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Least privilege for people and pods | `sec_lab1.md` | ✏️ | Today `module4/former-day4.md` Lab 1, **no step directories yet**. Steps 0–1 (a developer identity, lose cluster-admin) need cluster-admin: on the shared cluster, start from the attendee's real `trainee` rights instead. Steps 4–5 (short-lived tokens, escalation hunt) optional |
| Pod Security, network policies, secrets | `sec_lab2.md` | ✏️ | Today `module4/former-day4.md` Lab 2, **no step directories yet**. Part B overlaps `lab_network.md` step 5: keep one. Part C (SOPS / ESO / Vault): check what the shared cluster runs; the Linkerd authorization step is optional |

### Module 6 — Observability, CI/CD and troubleshooting

One 4 h session on GitOps with GitHub Actions and Flux (slides:
`module6_cicd.md` → `k8s_ci.md` theory, 35 min, then `gitops_lab.md`).
`github_advanced.md` and `gitops_theory.md` (deployment strategies,
Flagger) are gone; `ci_troubleshooting.md` is out of the session.

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| WordPress through a pipeline: two envs, deploy from CI (push) and its challenges, then Flux takes over, drift, tag-bump pipeline, promotion and rollback by PR, commit-status alerts | `gitops_lab.md` | 🆕 | **Nothing written yet.** To build in `module6/`, described below |

The application is the module 2 WordPress (Deployment + MySQL StatefulSet),
deployed twice in the attendee's namespace: `envs/dev` (1 replica) and
`envs/prod` (2), Kustomize overlays on one `k8s/base/`, told apart by
`nameSuffix` (`-dev` / `-prod`) and an `env` label with `includeSelectors`.
Each overlay merges `WORDPRESS_DB_HOST=mysql-<env>` and `APP_ENV=<env>` into
the base ConfigMap (kustomize renames objects, not env values) and patches
the Ingress host (`wordpress-dev.<ns>…`, `wordpress.<ns>…`). Quota: about
500m CPU / 1.3 GiB requested for both envs, 2 PVCs — the module 2–4
WordPress is deleted in the setup.

To write in `module6/` (commands run from `f021/`, the config repo cloned
in `$REPO`):

| Path | Content |
| --- | --- |
| `README.md` | conventions, prerequisites (GitHub account, classic PAT with `repo`, `workflow`, `read:packages`), setup and steps 1–7 |
| `repo/` | template of the config repo: `app/` (Dockerfile `FROM wordpress:6.8-apache` + a must-use plugin printing "`<env>` · `<version>`" in the footer: version as a build arg, env from the ConfigMap; files under `/usr/src/wordpress/` so the entrypoint copies them into the `emptyDir`), `k8s/base/` (Deployment with `imagePullSecrets: ghcr`, StatefulSet `mysql` 1Gi, Services, Ingress, ConfigMap, Secret `wordpress-db` referenced, not included), `envs/dev/`, `.github/workflows/image.yaml` (build, Trivy, push `ghcr.io/<repo>:<short sha>`). Namespace rendered in by the trainer at repo creation |
| `step1-envs/` | `envs/prod/` solution |
| `step2-push/` | `ci-deployer.yaml` (SA + RoleBinding `edit`), `ci-kubeconfig` (8 h token, API `srv2052563.hstgr.cloud:6443`, cluster CA), workflow with the `deploy` job (`kustomize edit set image`, `kubectl apply -k envs/dev`, `rollout status`) |
| `step3-flux/` | README only: the tenant is the trainer's; commit the running tag, delete the deploy job, `KUBECONFIG_DEV` and `ci-deployer` |
| `step4-drift/` | README only: scale, ConfigMap edit, unknown object, pruned file, suspend / resume |
| `step5-pipeline/` | `image.yaml` with the `bump-dev` job (set image, render + kubeconform, `peter-evans/create-pull-request`), `manifests.yaml` (on PR: render both envs, kubeconform, rendered diff comment) |
| `step6-promote/` | `CODEOWNERS` (`/envs/prod/`), `promote.yaml` (`workflow_dispatch`: dev `newTag` → prod, PR), a broken mu-plugin (PHP fatal) to promote and revert |
| `step7-alerts/` | `alert.yaml`: Flux `Provider` `github` (Secret `github-token`) + `Alert` on both Kustomizations; the breaking change (MySQL `volumeClaimTemplates` 1Gi → 2Gi in the base: valid schema, immutable at apply) |

Also needed, outside `module6/`:

- **Flux tenant** (`shared-cluster/templates/tenant-flux.yaml.tmpl`, then
  `make render`): two Kustomizations `wordpress-dev` / `wordpress-prod` on
  `./envs/dev` / `./envs/prod` instead of `sample-app` on `./deploy`, with
  `wait: true` and a `timeout` (step 7 relies on health). Same
  `serviceAccountName: flux`, prune, 1m. The "sample app" wording in
  `shared-cluster/README.md` (lab table, maintenance) to update with it.
- **Trainer's repo setup**, per attendee: `$GITHUB_OWNER/f021-<name>` from
  `module6/repo/`, the attendee as collaborator, first image built,
  *Allow GitHub Actions to create pull requests*, branch protection on
  `main` with one required review from code owners. Branch protection and
  private GHCR packages on a personal account: **check the plan** (private
  repos need GitHub Pro), or make the repos public. A script for this
  (`gh repo create --template`, `gh api` for the settings) belongs in
  `shared-cluster/` next to `make deploy-keys`.
- **`gh` in the console image** (`shared-cluster/console/`): the slides use
  `gh secret set/delete` and `gh workflow run`; without it, the GitHub web
  UI does the same.
- Check that GitHub-hosted runners reach the API server on 6443 (step 2).

### Module 7 — Best practices for operations and administration

| Lab | Slides | Status | Material |
| --- | --- | --- | --- |
| Create tenants (trainer demo) | `multi_tenancy.md` | ✏️ | `module1/exerciseA/tenant/` (quota, LimitRange, RBAC, NetworkPolicy). Needs cluster-admin: demo, or compare with the trainees' tenants in [`shared-cluster/tenants/`](shared-cluster/tenants/) |
| Backup and restore (trainer demo) | `backup.md` | ✏️ | Port `f021bis/module1/lab4/` step3-velero and step4-schedule; etcd steps stay in f021bis |
| Production checklist on WordPress and Bookinfo | `prod_checklist.md` | 🆕 | A checklist file to fill in, one line per item, each pointing to its module |

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
| `module4/former-day4.md` Slot 4 | audit workshop; red / blue team, policy-as-code, compliance evidence |
| `module5/README.md` Lab 1 | GitOps on Bookinfo: Flux tenant, SOPS vs ESO, Kyverno in the pipeline, Flagger canary on Linkerd |

## Other updates

- Every module README points to the former slides
  (`../../training_f021/slides/pages/moduleN.md`) and to "day N" of the
  former program: retarget to the new module pages.
- `CLAUDE.md` (training material in `../training_f021`, "Advanced
  Kubernetes"): update the name and path.
