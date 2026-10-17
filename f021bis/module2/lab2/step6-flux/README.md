# Step 6 — hand over to Flux, then drift

**Slides:** *Session 3* (`iac_workflows.md`) · **~15 min**

Ansible installs Flux and tells it where Git is; from then on, Flux applies
what is in Git, continuously. The application it gets is the trainer's:
[`lab2/fleet/`](../fleet/) of this repo, branch `master`.

## The playbook

`k8s/vars/flux.yml`:

| Variable | Value |
| --- | --- |
| `flux_version` | `FLUX_VERSION` (`versions.env`) |
| `flux_install_sha256` | `curl -sL https://github.com/fluxcd/flux2/releases/download/$FLUX_VERSION/install.yaml \| sha256sum` |
| `flux_git_url` | `https://github.com/jeanparpaillon/trainings_exercises` |
| `flux_git_branch` | `master` |
| `flux_git_path` | `./f021bis/module2/lab2/fleet` |

`k8s/flux.yml`, on `k8s_api`, `module_defaults` as before:

1. `ansible.builtin.get_url` of
   `https://github.com/fluxcd/flux2/releases/download/{{ flux_version }}/install.yaml`
   to `/tmp/flux-{{ flux_version }}-install.yaml`, with
   `checksum: sha256:{{ flux_install_sha256 }}`;
2. `kubernetes.core.k8s`, `src:` that file;
3. `k8s_info` on the Deployments of `flux-system` with label
   `app.kubernetes.io/part-of=flux`, waiting for `Available`. Give it a
   `wait_timeout` of 600: 7 images, ~330 MB, pulled from ghcr.io;
4. from two templates, in `flux-system`:
   - a `GitRepository` (`source.toolkit.fluxcd.io/v1`) `fleet`: `url`,
     `ref.branch`, `interval: 1m`;
   - a `Kustomization` (`kustomize.toolkit.fluxcd.io/v1`) `fleet`:
     `sourceRef` the GitRepository, `path`, `prune: true`, `interval: 1m`,
     `wait: true`, `timeout: 3m`;
5. `k8s_info` on that Kustomization, waiting for `type: Ready`.

```sh
ansible-playbook k8s/flux.yml
ansible-playbook k8s/flux.yml           # changed=0
kubectl -n flux-system get gitrepository,kustomization
kubectl -n gitops get deploy,pods
```

## Drift

Write down what you expect **before** each one, then try it and time it:

```sh
kubectl -n gitops delete deploy podinfo            # Flux's
kubectl -n web delete deploy web                   # Ansible's
kubectl -n gitops scale deploy podinfo --replicas=5
watch 'kubectl get deploy -A | grep -E "gitops|web"'
```

Then put `web` back the only way it comes back: `ansible-playbook
k8s/app.yml`.

During this step the trainer pushes a commit to `lab2/fleet/` (replicas 2 →
3). Watch `kubectl -n gitops get deploy podinfo -w`: nobody in the room runs
anything.

## The end of `iac`

```sh
git add -A && git commit -m "flux.yml" && git tag lab2
kind delete cluster --name iac           # lab 3 needs the memory
```

## Questions

- `kubectl -n gitops get deploy podinfo -o yaml | grep -A1 'manager:'`
  after the scale was reverted: who owns `spec.replicas`? What if an HPA
  should own it?
- Which of `app.yml`, `podinfo.yml`, `flux.yml` would you still run with
  Ansible on a production cluster, and which would you hand to Flux? What is
  left for Ansible once Flux is there?
