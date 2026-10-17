# Lab 2 — `kubernetes.core`, then Flux

**Slides:** *Session 2* (`ansible_k8s.md`), *Session 3* (`iac_workflows.md`),
then *Lab 2* (`lab_iac.md`) · **~70 min**

Ansible against the Kubernetes API, from the console: manifests from
templates, a Secret from Vault, a Helm release, a drain — then Flux takes
the application over, and drift shows the difference between the two. On a
throwaway kind cluster, `iac`; lab 3 runs `flux.yml` again on `spray`.

| Step | | ~ |
| --- | --- | --- |
| [step1-cluster](step1-cluster/) | cluster `iac`, the collection, `localhost` | 10 min |
| [step2-app](step2-app/) | an application from templates, a Secret from Vault | 15 min |
| [step3-state](step3-state/) | read back, wait, re-run, and what Ansible does not delete | 10 min |
| [step4-helm](step4-helm/) | a Helm release | 10 min |
| [step5-drain](step5-drain/) | an operation: cordon, drain, uncordon | 10 min |
| [step6-flux](step6-flux/) | hand over to Flux, then drift | 15 min |

| File | What it is |
| --- | --- |
| [`kind.yaml`](kind.yaml) | `iac`: 1 control plane (untainted, NodePort 30081 on 127.0.0.1) + 1 worker |
| [`step2-app/*.j2`](step2-app/) | the page, and the Deployment template to complete |
| [`fleet/`](fleet/) | what Flux deploys in step 6: namespace `gitops`, podinfo (trainer: the commit 2 → 3 replicas is made here) |
| [`solution/`](solution/) | `~/m2` at the end of the lab (lab 1's, plus `k8s/` and the `k8s_api` group); vaults encrypted with `m2-solution` |

Everything goes into `~/m2/k8s/`, and runs **from `~/m2`** (its
`ansible.cfg` and inventory):

```text
k8s/
  nodes.yml        step 1
  app.yml          steps 2, 3, 5 (PDB)
  podinfo.yml      step 4
  maintenance.yml  step 5
  flux.yml         step 6, and lab 3 step 9
  vars/{dev,prod,vault,podinfo,flux}.yml
  templates/
```

**Start**: lab 1 done (or `make catch-up-lab1` in `module2/`), venv active.

```sh
source ~/.venvs/m2/bin/activate
cd ~/m2
```

**End state** (start of lab 3): `~/m2` tagged `lab2`, with `k8s/`; `iac`
deleted. No catch-up target: `iac` is rebuilt in step 1 in two minutes, and
`lab2/solution/k8s/` can be copied as is.

## What was found on a local run

The solution was run end to end on kind v0.33.0 (`KIND_NODE`, Kubernetes
1.37.0), with the venv as `lab0` will build it: Kubespray v2.32.0's
`requirements.txt` (`ansible` 12.3.0, i.e. ansible-core 2.19), `kubernetes`
37.0.1, `kubernetes.core` 6.6.0 and `ansible.posix` 2.2.2 in
`~/.ansible/collections`, Helm v4.3.0. Not yet in the consoles. Flux pulled
`lab2/fleet` from a local git server with this repo's layout: the real URL
works once `lab2/fleet/` is pushed to `master`.

- **The repo's branch is `master`**, not `main`: `flux_git_branch: master`.
- **Action groups** of `kubernetes.core` 6.6.0: `group/kubernetes.core.k8s`
  (`k8s`, `k8s_info`, `k8s_drain`, … ) and `group/kubernetes.core.helm`
  (`helm`, `helm_info`, `helm_repository`, …). **Lookups get no
  `module_defaults`**: the lookup of step 3 passes `kubeconfig`/`context`
  itself.
- **Helm v4.3.0 works** with `kubernetes.core.helm` 6.6.0, no `binary_path`.
- **`ansible_become: false`** on `localhost`: `ansible.cfg`'s `become = true`
  would otherwise run `sudo` in the console.
- **Idempotent**: `app.yml`, `podinfo.yml`, `flux.yml` second runs are
  `changed=0`, a `stringData` Secret included. Every `kubernetes.core.k8s`
  task prints a `DEPRECATION WARNING` (`environment` attribute) on
  ansible-core 2.19: the collection's, not ours.
- **The `assert` of step 3 fails in check mode** (the cluster still has the
  old replica count): `when: not ansible_check_mode`. The `--diff` of a
  `k8s` task is the whole object, `managedFields` included.
- **No control-plane taint** via a kubeadm patch in `kind.yaml` (instead of
  module 1's `kubectl taint`): the drain moves `web` to the control plane,
  the PDB holds, the pods stay there after the uncordon.
- **Flux's first install took 5 min 44 s**, all of it image pulls: v2.9.6's
  `install.yaml` has 7 controllers (image automation, image reflector and
  `source-watcher` included), ~330 MB from ghcr.io. Hence the 600 s wait.
  With 4 pairs at once, pre-pulling them in `lab0` is worth considering.
- **Drift**, as on the debrief slide: Flux's deleted Deployment back in 28 s;
  Ansible's stays deleted; `scale --replicas=5` reverted to 2 in 71 s (the
  `kubectl` field manager is removed); a commit 2 → 3 followed in 40 s.
