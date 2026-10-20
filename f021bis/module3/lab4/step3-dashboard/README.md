# Step 3 — the cluster dashboard

**Slides:** *Dashboards* · **~10 min**

The first screen the on-call opens at 3 am: the problems first, then
enough to tell which layer is failing — the nodes, the workloads, the
application, and the monitoring itself.

## The monitoring itself

Is the proxy keeping up? It knows: its own internal items. A host for it,
*Data collection → Hosts → Create host*: `<name> proxy`, group `<name>`,
no interface, monitored by proxy `<name>`, template *Zabbix proxy health*
(*Templates/Applications*). Its items (*Queue*, *Queue over 10 minutes*,
*Preprocessing queue*…) arrive within a minute.

## The dashboard

*Dashboards → Create dashboard*, `<name> mon` (yours: owner `<name>`).
Widgets, in this order:

| Widget | Type | Settings |
| --- | --- | --- |
| Problems: `<name>` | *Problems* | host groups `<name>`; *Show suppressed problems* |
| Problems: the nodes | *Problems* | hosts `mon-<name>-control-plane`, `mon-<name>-worker` |
| Nodes: CPU utilization | *Graph* | host pattern `mon-<name>-*`, item pattern `CPU utilization` |
| Nodes: memory utilization | *Graph* | the same, `Memory utilization` |
| Nodes: ready | *Graph* | host `<name> mon nodes`, item pattern `Node [*] Conditions: Ready` |
| podinfo: requests and 5xx per second | *Graph* | host `<name> podinfo`, two data sets: `podinfo: requests per second`, `podinfo: 5xx per second` |
| podinfo: p95 | *Item value* | `<name> podinfo`, `podinfo: p95 latency` |
| Proxy `<name>`: queue | *Graph* | host `<name> proxy`, item `Queue` |

Two problem widgets: the discovered node hosts are not in your group, and
their group, `Applications`, has everyone's.

Short of time: [`../solution/dashboard.json`](../solution/dashboard.json)
is this dashboard with names instead of ids;

```sh
lab0/render lab4/solution/dashboard.json > /tmp/dashboard.json && lab0/dashboard /tmp/dashboard.json
```

creates it (and replaces yours, if it has the same name).

## Questions

- What is on your first screen, and what did you leave out? (The cluster
  state template's ~300 items: which three would you put here?)
- Why the proxy's queue? What does the dashboard look like when the proxy
  is down — and which widget tells you?
- Template dashboards (*Data collection → Templates*, *Dashboards*) are
  one per host linked to the template: what would you put in `<name>
  podinfo by HTTP`'s, for every podinfo?
