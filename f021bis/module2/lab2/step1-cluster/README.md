# Step 1 — cluster `iac`, the collection, `localhost`

**Slides:** `kubernetes.core` — overview · **~10 min**

Lab 1 drove nodes over SSH. Here nothing goes to the nodes: the tasks run in
your console and talk to the API server, like `kubectl`.

## The cluster

```sh
cd ~/trainings_exercises/f021bis/module2 && source versions.env && cd ~/m2
kind create cluster --name iac \
  --config ~/trainings_exercises/f021bis/module2/lab2/kind.yaml --image "$KIND_NODE"
kubectl config current-context          # kind-iac
kubectl get nodes
```

Read [`kind.yaml`](../kind.yaml): a NodePort published on `127.0.0.1:30081`,
and no taint on the control plane (step 5 needs two schedulable nodes).

## The collection and its client

```sh
ansible-galaxy collection list kubernetes.core   # which one wins, and why?
python -c 'import kubernetes; print(kubernetes.__version__)'
ansible-doc kubernetes.core.k8s_info               # EXAMPLES, at the end
```

Two `kubernetes.core` show up: the one `lab0` pinned in
`~/.ansible/collections`, and the one bundled with the `ansible` package
Kubespray's `requirements.txt` installs. The first path wins.

## `localhost` in the inventory

Add to `inventory/hosts.yml` a group `k8s_api` with one host, `localhost`.
Its variables in `inventory/group_vars/k8s_api/main.yml`:

| Variable | Value | Why |
| --- | --- | --- |
| `ansible_connection` | `local` | no SSH: the task runs in the console |
| `ansible_python_interpreter` | `"{{ ansible_playbook_python }}"` | the venv's Python, the one that has the `kubernetes` client — not `/usr/bin/python3` |
| `ansible_become` | `false` | `ansible.cfg` says `become = true`, for the nodes; here it would mean `sudo` in the console |
| `k8s_kubeconfig` | `~/.kube/config` | which credentials… |
| `k8s_context` | `kind-iac` | …for which cluster; lab 3 overrides both with `-e` |

## The first playbook

`k8s/nodes.yml`: one play on `k8s_api`, `gather_facts: false`, a
`kubernetes.core.k8s_info` on `kind: Node` registered, and a `debug` of the
nodes' names (`map(attribute='metadata.name')`).

Do not repeat `kubeconfig:` and `context:` on every task: give them once,
to every module of the collection's action group, with

```yaml
  module_defaults:
    group/kubernetes.core.k8s:
      kubeconfig: "{{ k8s_kubeconfig }}"
      context: "{{ k8s_context }}"
```

```sh
ansible-playbook k8s/nodes.yml          # from ~/m2: ansible.cfg and the inventory are there
ansible-playbook k8s/nodes.yml -e k8s_context=nope      # what does the error say?
git add -A && git commit -m "k8s_api, nodes.yml"
```

## Questions

- Where does the `k8s_info` task run, and what does it need on `node1`?
- What credentials does this playbook use, and what may they do in `iac`?
  What would you give a CI pipeline instead?
