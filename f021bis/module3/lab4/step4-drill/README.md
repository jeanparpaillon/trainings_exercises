# Step 4 — incident drill

**Slides:** *Lab 4 — goal* · **~15 min**

Two faults, one after the other. For each: write down what Zabbix should
show **before** breaking anything; then only the Zabbix UI (the dashboard
of step 3, *Monitoring → Problems*) until you can name the cause; then fix
it with `docker` / `kubectl`, and note the times.

## First: where does the monitoring run?

```sh
kubectl -n monitoring get pods -o wide
```

On the dry run, after lab 3, the proxy and kube-state-metrics were on the
**worker** — wherever the scheduler put them; look at yours. The control
fault pauses the worker. What would Zabbix show then, with the proxy on
it? (Nothing about the cluster at all: the proxy that
collects it would be frozen with the node. The server would only see a
proxy that stopped talking.)

The monitoring must not run on what fails. In `~/m3/values.yaml`, add to
`zabbixProxy:`

```yaml
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
```

and at the end, for the chart's kube-state-metrics:

```yaml
kube-state-metrics:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
```

```sh
helm upgrade zabbix lab0/charts/zabbix-helm-chart-$ZABBIX_CHART_VERSION.tgz -n monitoring -f ~/m3/values.yaml --wait
kubectl -n monitoring get pods -o wide        # proxy and kube-state-metrics on mon-<name>-control-plane
```

(~30 s. The proxy restarts: `<name> proxy` reports it, as an
*Information*.) The agents stay a DaemonSet, one per node: the worker's
goes down with the worker, by design.

## The two faults

| Fault | Apply | What it does |
| --- | --- | --- |
| control | `lab4/break control` | `docker pause mon-<name>-worker`: the node, its kubelet, its agent, podinfo and the load pod freeze |
| workload | `lab4/break workload` | the load pod asks only for `/status/500` |

`lab4/reset` undoes either (and waits for both nodes to be Ready).
`lab4/break` prints the time it applied the fault: your time to detect
starts there.

For each, before running it, write down:

1. which problems should open, on which host, in what order, roughly when;
2. which should **not** — the step 1 dependency, the action's filter;
3. which message the action of step 2 sends.

Then break, watch, name the cause, fix (`lab4/reset`), and write down when
the first problem opened and when the first message was *Sent*.

## What the dry run showed

Control fault, run twice:

| +s after `break control` | Kubernetes | Zabbix |
| --- | --- | --- |
| 49–50 | worker `NotReady` | |
| 60–88 | | *Node [mon-<name>-worker] Conditions: Is not in Ready state* (Warning, on `<name> mon nodes`); **sent** 1–2 s later (condition E of the action) |
| — | | podinfo's *no data*: **nothing** while the node was not ready — the dependency held |
| — | | the discovered `mon-<name>-worker`: **nothing at all**. The proxy logged network errors to its agent for 50 s, then nothing; no *agent not available* |
| 299–334 | | *Deployment replicas mismatch*, *ReplicaSet mismatch* for `podinfo` and `load` (Warning: not sent) |
| reset, then +0 | worker `Ready` | |
| +11–48 | | node problem resolved, *Resolved* sent |
| +1 after that | | **podinfo's *no data* opened and was sent**, then resolved 30 s later |

Workload fault:

| +s after `break workload` | Zabbix |
| --- | --- |
| 101 | *podinfo: 5xx above 1/s for 2 min* (High), on `<name> podinfo`; sent 7 s later |
| — | nothing else: no node, cluster state or Kubernetes problem — the pods are *Running* and *Ready* |
| reset, then +65 | resolved |

## Questions

- Control fault: how long until the node was *not ready* in Kubernetes,
  and in Zabbix? Where does the difference come from (the node monitor
  grace period, the template's 1 min poll at second 00)?
- Did the dependency hold? And at the end — what paged once the node came
  back, and why? (The dependency lifts the moment the node is ready;
  podinfo has not been read yet, and its *no data* is still true.)
- The Linux template on the node host saw nothing. Which template told
  you the node was gone: the one that talks to the node, or the one that
  asks the API about it?
- Workload fault: which template saw it? Would the shipped Kubernetes
  templates alone have seen anything?
