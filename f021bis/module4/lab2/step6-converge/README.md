# Step 6 — run twice, then change the page only

**Slides:** *Convergence tests* · **~5 min**

## Converged

```sh
ansible-playbook web.yml
ansible-playbook web.yml          # PLAY RECAP: changed=0 on node1 and node2
```

Anything still `changed` on the second run is a bug: find it before going
on.

## Change the page only

To tell whether nginx restarted, note the time its main process started:

```sh
ansible web -m ansible.builtin.command -a 'systemctl show nginx -p ExecMainStartTimestamp'
```

1. Change the text of the page in `web.yml` (`Hello from` → `Served by`)
   and run: the page task is `changed`; **no** handler; same start time;
   `curl http://node1` shows the new text.
2. Change `worker_processes` to `4` in `files/nginx.conf` and run: the
   handler runs **once** per host; new start time;
   `ansible web -m ansible.builtin.command -a 'pgrep -c -u nginx'` (the
   workers run as `nginx`, the master as root) says `4`.
3. Add `notify: Restart nginx` to the page task too, then change **both**
   the page and the config in one go. How many times does the handler run?

Put the page back to `Hello from` and the config to 2 workers (and remove
the extra `notify:`), run until `changed=0`, then:

```sh
ansible-playbook web.yml --check --diff     # nothing would change
git add -A && git commit -m "lab 2" && git tag lab2
```

## Questions

- A task **after** the config copy fails on `node1` in the run that changed
  the config. Does the handler run on `node1`? On `node2`? You fix the
  failing task and run again: is nginx on `node1` restarted now? What do
  `--force-handlers` and `meta: flush_handlers` change?
- A restart drops the connections in progress. What would a handler with
  `state: reloaded` do instead, and why is `nginx -t` before it a good
  idea? (Lab 3 step 4 comes back to it.)
