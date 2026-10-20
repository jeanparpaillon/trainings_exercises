# Lab 4 — Alert, dashboard, incident

**Slides:** *Alerts, dashboards, incidents*, *Alternative: Prometheus
alerts into Zabbix* (`zabbix_alerting.md`), then *Lab 4*
(`lab_zabbix_alert.md`) · **~55 min**

Three labs collected everything; nothing tells anyone yet. Here: triggers
that mean something and stay quiet when the cause is elsewhere, an action
for your problems only, a maintenance, the on-call's first screen — then
two faults in `mon`, found from Zabbix alone.

| Step | | ~ |
| --- | --- | --- |
| [step1-triggers](step1-triggers/) | triggers and dependencies | 15 min |
| [step2-action](step2-action/) | an action, a maintenance | 10 min |
| [step3-dashboard](step3-dashboard/) | the cluster dashboard | 10 min |
| [step4-drill](step4-drill/) | incident drill | 15 min |
| [step5-note](step5-note/) | incident note, export | 5 min |

| File | What it is |
| --- | --- |
| [`break`](break) | `lab4/break control` (worker paused) or `workload` (load pod on `/status/500` only); prints the time |
| [`reset`](reset) | undoes either; waits for both nodes to be Ready |
| [`solution/`](solution/) | `~/m3` at the end of the lab: `values.yaml` (proxy and kube-state-metrics on the control plane), `templates/podinfo.yaml` (lab 3's, plus `{$PODINFO.ERRORS.MAX}` and three triggers), `hosts/` (plus `proxy.yaml`), `dashboard.json` (names, not ids: `lab0/dashboard`) |

**Start**: lab 3 done (or `make catch-up-lab3`), from `module3/`:

```sh
cd ~/trainings_exercises/f021bis/module3
source versions.env
source ~/.zabbix/user.env
kubectl config current-context        # kind-mon-<name>
```

The trainer has run `make zabbix-users` with media type `Lab webhook`
(`bin/zabbix`, from 2026-10-20): your user has a media of that type.

**End state** (end of the module): triggers in `<name> podinfo by HTTP`,
podinfo's depending on the worker's *not ready*; action `<name> pages`;
host `<name> proxy`; dashboard `<name> mon`; the proxy and
kube-state-metrics on the control plane; `~/m3` tagged `lab4`. Then
`kind delete cluster --name "$CLUSTER"`; the trainer runs `make
zabbix-users-delete`.

Catch-up (from `module3/`): `make catch-up-lab4` — `catch-up-lab3` with
lab 4's solution, then the dependencies (`lab0/depend`, waiting for the
node discovery) and the dashboard (`lab0/dashboard`). Not the action:
not part of an export (step 5).

## Validated on the server

2026-10-20, in `console-jean`, on `mon-jean` at the end of lab 3: every
step through the API (the UI forms were not clicked through), the drill
run as written (control fault twice, workload once), then `make
catch-up-lab4` on the existing `mon`: 1 min 29 s, the three dependencies
set again once the node trigger was found, the dashboard recreated; the
template exported afterwards equals the solution but for its uuids. Found
there, against the spec:

- **The proxy ran on the worker** (and kube-state-metrics): pausing it
  would have blinded Zabbix rather than tested it. Step 4 moves both to
  the control plane first (`nodeSelector`), as a lesson of its own.
- **`nodata()` on the master item never fires**: its history is *Do not
  store*, and the trigger sits in state *unknown*, `Cannot evaluate
  function nodata(…): item history is disabled` — silently, from the
  start. On a stored dependent item (`podinfo.started`) it fired 95 s into
  an outage (2 min window), unsupported item and all. Lab 3's slide said
  "one trigger on the master".
- **The shipped *node not ready* is a Warning** (and on the parent host
  `<name> mon nodes`, not on the node's host): an action on *Average and
  above* never sends it. The action adds a condition on its name.
- **Validated** (spec's *to validate*): a tenant can use read-only
  discovered hosts in an action's conditions; a maintenance on a
  discovered host is refused (`No permissions to referred object`); on its
  own group it suppresses the problem (shown with *Show suppressed*), the
  action's operations wait, and the message goes 30 s after the
  maintenance ends.
- **Dependencies**: a template trigger may depend on another host's
  discovered trigger, and so may a host's inherited trigger. The lab sets
  it on the host (only the host knows its node). **Not exported** — like
  lab 2's lifetimes: `lab0/depend` sets it again.
- **Drill timings**: control — Kubernetes `NotReady` at 49–50 s, Zabbix
  60–88 s, sent within 2 s; *replicas mismatch* Warnings at 299–334 s;
  podinfo silent while the node was not ready, then its *no data* paged
  1 s after the node problem resolved (recovery flap). Workload — the
  error-rate trigger at 101 s, nothing else.
- **The discovered node host saw nothing** while the worker was paused:
  its agent checks failed for 50 s (proxy log), then no value, no *agent
  not available*, interface still *available*. Not explained.
- **Delaying the action** (step 5's change: operations from step 2, 2 min
  steps): a 1 min problem sent nothing at all; a 3.5 min one was sent
  121 s after it opened.
- **Media**: every media type on the server was disabled and the tenants
  had none. Decided: `bin/zabbix users` creates `Lab webhook` (a webhook
  that logs and returns OK) and gives each tenant user a media of it —
  nothing to run, and the messages are visible in the problems' *Actions*.
- `min(…,2m)` evaluates history already stored: lowering the threshold
  opened the problem in 30 s, not 2 min.
