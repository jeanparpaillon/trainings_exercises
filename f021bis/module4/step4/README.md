# Step 4 — template

**Slides:** *Step 4* · **~30 min** (5 theory, 25 exercise), alone ·
EX407: *create and use Ansible templates to create customized
configuration files for hosts*

**One** template, a **different** file on each host: the home page of
httpd, from facts and variables. And a configuration snippet whose change
restarts httpd — once, and only when it changed.

| | What | ~ |
| --- | --- | --- |
| 1 | `web_title` in `group_vars/web.yml` | 2 min |
| 2 | `templates/index.html.j2`: name, IP, OS | 10 min |
| 3 | `templates/m4.conf.j2` + handler | 8 min |
| 4 | change the page, then the snippet | 5 min |

Commit, tag `step4`.

**Start**: step 3's end state. If not: `make catch-up-step3`.

## 1 — a variable for `web`

`~/m4/group_vars/web.yml`: `web_title: Module 4`. Only `node1` and `node2`
see it:

```sh
ansible all -m debug -a var=web_title      # node3: VARIABLE IS NOT DEFINED!
```

## 2 — the page

`~/m4/templates/index.html.j2` → `/var/www/html/index.html`, a task in
`web.yml` (the `template` module; `src:` is looked for in `templates/`
next to the playbook). The page shows:

- `web_title`, with a **default** (`| default('m4')`) so the template does
  not fail where it is not defined;
- the host's inventory name;
- its IP address and its distribution with its version, from **facts**;
- the members of the group `web`, with a `{% for %}` loop.

Find the facts yourself:

```sh
ansible node1 -m setup -a 'filter=ansible_distribution*'
ansible node1 -m setup -a 'filter=ansible_default_ipv4'
```

`ansible_default_ipv4` is empty on a host with no default route: then
`| default(ansible_all_ipv4_addresses | first)`.

## 3 — the snippet, the handler

`~/m4/templates/m4.conf.j2` → `/etc/httpd/conf.d/m4.conf`, two lines:

```apache
ServerName {{ inventory_hostname }}
Header set X-Managed-By ansible
```

Its task **notifies** a handler `Restart httpd` (service restarted),
declared in the play's `handlers:`. The page task notifies nothing: a new
page needs no restart.

## 4 — run, then change one thing at a time

```sh
ansible-playbook site.yml
ansible-playbook site.yml                 # changed=0
curl http://node1 ; curl http://node2      # different names and IPs
curl -sI http://node1 | grep X-Managed-By
```

To tell whether httpd restarted, note when its main process started:

```sh
ansible web -m command -a 'systemctl show httpd -p ExecMainStartTimestamp'
```

1. Change the page template only (the title, a line) and run: the page
   task is `changed`, **no** handler, same start time.
2. Change the snippet only (a second header) and run: the handler runs
   **once** per host, new start time.

```sh
git add -A && git commit -m "step 4" && git tag step4
```

End state (start of step 5): `~/m4` tagged `step4`, with `templates/`,
`group_vars/web.yml`, `web.yml` with the two template tasks and the
handler; on `node1` and `node2`, the page and the snippet in place. From
nothing: `make catch-up-step4`.

## Questions

- Add `notify: Restart httpd` to the page task too, then change **both**
  templates in one run. How many times does the handler run?
- A task **after** the snippet fails on `node1` in the run that changed the
  snippet. Does the handler run on `node1`? Fix the task and run again: is
  httpd on `node1` restarted now? (`--force-handlers`.)
- Why is `template` idempotent and `shell: echo … > index.html` not?
