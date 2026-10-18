# Step 9 — the whole chain: lab 2's `flux.yml` on `spray`

**Slides:** *IaC end to end* · **~10 min**

`flux.yml` was written for `iac` in lab 2. Nothing in it is about kind: only
the connection changes.

```sh
kubectl --kubeconfig ~/m2/inventory/artifacts/admin.conf config current-context
ansible-playbook k8s/flux.yml \
  -e k8s_kubeconfig=~/m2/inventory/artifacts/admin.conf \
  -e k8s_context=kubernetes-admin-spray.local@spray.local
kubectl -n flux-system get gitrepository,kustomization
kubectl -n gitops get deploy,pods -o wide
```

The same `lab2/fleet/` the trainer changed during lab 2 now runs on `spray`.

```sh
git commit --allow-empty -m "flux on spray" && git tag lab3c
```

## The chain, as commands

Write down, from three empty containers to an application reconciled from
Git, every command — the slide *IaC end to end* is filled with the room's
lists:

1. `make -C lab0 up` — the machines
2. `ansible-playbook site.yml` — the nodes (lab 1)
3. `ansible-playbook -i inventory ~/kubespray/cluster.yml` — the cluster (lab 3)
4. `ansible-playbook k8s/flux.yml -e …` — the platform hands over to Git (lab 2)
5. a commit in `lab2/fleet/` — the application

## Questions

- Which of these steps would you run again, and when? Which one runs by
  itself, continuously?
- What is **not** in Git in this chain, and where does it live? (Think:
  `~/.vault_pass`, `admin.conf`, the nodes' disks, `~/kubespray`.)

At the end of the module: `make -C ~/trainings_exercises/f021bis/module2/lab0 down`.
