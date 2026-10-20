# Step 3 — a config file, and a handler to restart

**Slides:** *Facts, variables, `when`, `loop`, handlers* · **~10 min**

Given: [`nginx.conf`](nginx.conf), a complete nginx configuration (2
workers, port 80, the page of step 2, a header `X-Managed-By: ansible`).
Lab 3 turns it into a template.

```sh
mkdir -p ~/m4/files
cp ~/trainings_exercises/f021bis/module4/lab2/step3-config/nginx.conf ~/m4/files/
```

Add to `web.yml`:

1. a task that copies it to `/etc/nginx/nginx.conf` — `src: nginx.conf`,
   no path: `copy` looks in `files/` next to the playbook — and
   **notifies** `Restart nginx`;
2. a `handlers:` section, at the level of `tasks:`, with one handler named
   exactly `Restart nginx` that restarts the service.

Where does the task go in the list? It must run **after** the package is
installed — think about what the package does to `/etc/nginx/nginx.conf`.

## Check

```sh
ansible-playbook web.yml          # RUNNING HANDLER [Restart nginx]
ansible-playbook web.yml          # no handler
ansible web -m ansible.builtin.command -a 'grep worker_processes /etc/nginx/nginx.conf'
git add -A && git commit -m "web.yml: config, handler"
```

## Questions

- The handler ran on the first run, yet nginx was not running before.
  What does `state: restarted` do to a stopped service?
- Misspell the handler name in `notify:` (`restart nginx`, lower case)
  and run. Then change the config and run again. Why does the mistake
  show up only the second time — and why is that dangerous in an exam?
