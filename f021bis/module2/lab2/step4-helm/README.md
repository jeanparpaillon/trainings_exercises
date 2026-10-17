# Step 4 — a Helm release

**Slides:** `kubernetes.core` — main modules (Helm) · **~10 min**

Not every application comes as manifests: podinfo comes as a chart.
Ansible does not render it — it drives the `helm` binary of the console.

## The playbook

`k8s/vars/podinfo.yml`:

```yaml
podinfo_chart_version: 6.15.0        # PODINFO_CHART_VERSION
podinfo_values:                      # what `helm -f values.yaml` would read
  replicaCount: 2
  ui:
    message: deployed by Ansible, with Helm
  resources:
    requests: { cpu: 10m, memory: 32Mi }
    limits: { memory: 64Mi }
```

`k8s/podinfo.yml`, on `k8s_api`, with `module_defaults` for the **other**
action group, `group/kubernetes.core.helm` (same two keys):

1. `kubernetes.core.helm_repository`: `podinfo`,
   `https://stefanprodan.github.io/podinfo`;
2. `kubernetes.core.helm`: release `podinfo`, `chart_ref: podinfo/podinfo`,
   `chart_version`, `release_namespace: podinfo`, `create_namespace: true`,
   `values: "{{ podinfo_values }}"`, `wait: true`;
3. `kubernetes.core.helm_info` registered, and a `debug` of its
   `status.revision`, `status.status`, `status.chart`.

```sh
ansible-playbook k8s/podinfo.yml
ansible-playbook k8s/podinfo.yml          # changed=0
helm list -A
```

## A new revision

`replicaCount: 1`, run, then

```sh
helm history podinfo -n podinfo
kubectl -n podinfo get pods
git add -A && git commit -m "podinfo.yml"
```

## Questions

- What does the module compare to decide `changed`? (Hint: run with `-vvv`
  and look for `helm get values`.) Change something in the chart that is
  **not** a value — would it see it?
- `helm rollback podinfo 1 -n podinfo`, then run the playbook. Who is right,
  and what is the revision number now?
