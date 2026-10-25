# Module 4 — monitoring, logging and troubleshooting

Exercises for module 4 of **F021**. The slides are in the `trainings` repo,
`f021/slides/pages/module4_monitoring.md`.

| | Lab | Slides | ~ |
| --- | --- | --- | --- |
| — | **no monitoring lab**: Prometheus and Grafana are a trainer demo | `monitoring.md`, last slide | 15 min |
| [troubleshoot/](troubleshoot/) | troubleshooting scenarios: `break`, find it with the method, `check` | `troubleshooting.md`, then `lab_troubleshooting.md` | 60 min |

The audience writes applications, not monitoring stacks: the demo shows
where to look, the lab is spent on finding faults. Every path below is
relative to this directory:

```sh
export NS=<your-namespace>
cd module4
```

## Starting state

The namespace as module 3 left it: Bookinfo at `module3/harden/step4-spread`,
WordPress back at one replica with its data, no NetworkPolicy, no k6 Job
left. Not sure? Then:

```sh
troubleshoot/reset        # back to exactly that state, with your own rights
```

`reset` needs the files rendered in module 1 (the Bookinfo and WordPress
Ingresses) and the WordPress Secret: it applies your checkout, edits
included — the memory you gave `ratings` in module 3 among them.

## The lab

Everything is in [`troubleshoot/README.md`](troubleshoot/README.md): seven
scenarios in four groups (application, network, Kubernetes objects,
storage), each injected silently into your own namespace by
`troubleshoot/break <n>`, checked by `troubleshoot/check <n>`. Fix the
object, not with `reset`; note what each command ruled out.

`break` and `check` load the page through the Ingress, from wherever they
run: the web console on the shared cluster (`bookinfo.<ns>.195.35.2.222.nip.io`),
or with `export NIP=127.0.0.1.nip.io` on a local kind cluster.

## For the trainer

Before the session, on the shared cluster:

- **The demo** (`monitoring.md`, *Demo — your namespace in Grafana*) runs
  in the trainer's own namespace: bring it to the end of module 3 and start
  a k6 run (`module3/harden/k6/constant-load.yaml`) so the graphs move.
  Grafana at `https://grafana.srv2052563.hstgr.cloud/`, console logins.
- **Logging**: no log stack is installed (`shared-cluster/README.md`):
  `kubectl logs` only, in the lab and in `logging.md`.
- **Scenario 6** (DNS blocked by a NetworkPolicy) needs the CNI to enforce
  NetworkPolicy: same check as the module 2 network lab, step 4.
- **Scenario 5** (rollout stuck on the quota) computes its memory request
  from the quota's `status.used` at `break` time: run it with no k6 Job and
  no module 1 leftovers in the namespace, or the margin is off.
- Run the seven scenarios once in a trainee namespace:
  `break n`, check the symptom, apply the fix of the *For the trainer*
  section of `troubleshoot/README.md`, `check n`, `reset`.

## Former material

[`former-day4.md`](former-day4.md) is the former day 4, security and
advanced governance: the starting point of the module 5 labs, not used as
is.
