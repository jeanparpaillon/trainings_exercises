# Lab 2 — a web service, idempotent

**Slides:** *Session 2* (`module4_session2.md`), *Lab 2* · **~40 min**,
alone

One playbook, `web.yml`, that installs, configures and starts **nginx** on
the group `web`, opens HTTP in the firewall, and creates users from a list;
restarts nginx **only** when its configuration changes; and does nothing
on its second run. Lab 3 turns its static `nginx.conf` into a template.

| Step | | ~ |
| --- | --- | --- |
| [step1-install](step1-install/) | install the web server on `web` | 5 min |
| [step2-page](step2-page/) | deploy a page with the host name in it | 10 min |
| [step3-config](step3-config/) | config file + handler to restart | 10 min |
| [step4-service](step4-service/) | open the port, start and enable the service | 5 min |
| [step5-users](step5-users/) | users from a list with `loop` | 5 min |
| [step6-converge](step6-converge/) | run twice, then change the page only | 5 min |

| File | What it is |
| --- | --- |
| [`step3-config/nginx.conf`](step3-config/nginx.conf) | given: the whole nginx configuration, copied to `~/m4/files/` |
| [`solution/`](solution/) | `~/m4` at the end of the lab: lab 1's files, `web.yml`, `files/nginx.conf` |

**Start**: lab 1's end state — `~/m4` tagged `lab1`, and

```sh
cd ~/m4 && ansible all -m ansible.builtin.ping     # green, no option
```

If not: `make catch-up-lab1` in `~/trainings_exercises/f021bis/module4`.

**End state** (start of lab 3): `~/m4` tagged `lab2`, with `web.yml` and
`files/nginx.conf`; on `node1` and `node2`: nginx installed, configured
from that file, running and enabled, HTTP open in firewalld, the page
`Hello from <host>`, users `alice` and `bob`; a second run of `web.yml`
reports `changed=0`. From nothing: `make catch-up-lab2` in `module4/`
(lab 1's chain, then `web.yml`).

## What was found on a local run

Run on a laptop against `lab0`'s nodes from an `ubuntu:24.04` stand-in for
the console (ansible-core 2.16.3), **with the nodes' default route
removed**: everything below worked with no Internet access on the nodes.

- `make catch-up-lab2` from blank nodes: 18 s (bootstrap, ad hoc,
  `web.yml`); `web.yml` first run `changed=7` per host, second run
  `ok=7 changed=0`. `curl http://node1` → `Hello from node1`, header
  `X-Managed-By: ansible`; `curl http://node3` refused (firewalld).
- **`ansible.builtin.dnf` installs weak dependencies** (`install_weak_deps`
  defaults to `true` in the module, whatever `dnf.conf` says): nginx pulls
  `logrotate` that way, and a first image built without weak deps failed
  offline on it. `lab0`'s image now downloads them.
- Step 6, measured: page only → page task `changed`, no handler, same
  `ExecMainStartTimestamp`; config only → handler once per host, new
  timestamp, `pgrep -c -u nginx` = workers; page and config both
  notifying → handler **once**.
- **A misspelled handler is silent** until a notifying task is `changed`;
  then `ERROR! The requested handler 'restart nginx' was not found …`
  aborts the run at that task (ansible-core 2.16).
- **A failure after the notify** (a `fail` task on `node1`): the handler
  runs on `node2` only; `node1` keeps the new file and the old process —
  and the **next** run does not restart it either (the file is already in
  place, nothing notifies). `--force-handlers` runs it despite the failure.
