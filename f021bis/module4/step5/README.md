# Step 5 — role

**Slides:** *Step 5* · **~30 min** (5 theory, 25 exercise), alone, guided ·
EX407: *create Ansible roles*

Step 2–4's web tasks, templates and handler move into a role, `httpd`;
`web.yml` only calls it. Nothing changes on the hosts: the proof is a run
that says `changed=0` straight away — then a rebuild from blank hosts.

| | What | ~ |
| --- | --- | --- |
| 1 | `ansible-galaxy init roles/httpd` | 2 min |
| 2 | tasks, templates, handler, default | 13 min |
| 3 | `web.yml`: `roles: [httpd]` | 2 min |
| 4 | from clean hosts, run twice | 8 min |

Commit, tag `step5`.

**Start**: step 4's end state. If not: `make catch-up-step4`.

## 1 — the skeleton

```sh
ansible-galaxy init roles/httpd
find roles/httpd
```

`.travis.yml` and `tests/` are for publishing on Galaxy: delete them.
Fill in `meta/main.yml`'s `author` and `description`, and the role's
`README.md` (what it does, its variables).

## 2 — move each piece to its place

| From | To |
| --- | --- |
| `web.yml`'s `tasks:` | `roles/httpd/tasks/main.yml` — a **list of tasks**: no `hosts:`, no `tasks:` key |
| `web.yml`'s `handlers:` | `roles/httpd/handlers/main.yml` |
| `templates/*.j2` | `roles/httpd/templates/` — `src:` stays the bare file name |
| a default for `web_title` (`m4`) | `roles/httpd/defaults/main.yml` |

`group_vars/web.yml` stays where it is: the inventory's `web_title` beats
the role's default — that is what a default is for.

## 3 — `web.yml`

The play keeps its `name:` and `hosts: web`, and has only `roles:` with
`httpd` in it.

```sh
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --list-tasks     # httpd : httpd is installed, …
ansible-playbook site.yml                  # changed=0: the hosts are the same
```

Anything `changed` here is a mistake in the move (a template's content, a
path, a mode): fix it before going on.

## 4 — from clean hosts

The role must also **build** the hosts, not only agree with them:

```sh
make -C ~/trainings_exercises/f021bis/module4 reset    # blank nodes, new host keys
./bootstrap.sh                                         # step 1, root's password
ansible-playbook site.yml                              # changed > 0
ansible-playbook site.yml                              # changed=0
curl http://node1
git add -A && git commit -m "step 5" && git tag step5
```

Short on time: skip the reset — the `changed=0` of sub-step 3 already
proves the move.

End state (start of step 6): `~/m4` tagged `step5`, with `roles/httpd/`
and a `web.yml` of five lines; the hosts as at the end of step 4. From
nothing: `make catch-up-step5`.

## Questions

- Put `web_title: Role vars` in `roles/httpd/vars/main.yml`. Which title
  does `curl` show, and why is that a trap? (Empty it again.)
- `roles:` and `tasks:` in the same play: which run first?
- Where would a second web server role find `index.html.j2` if it needed
  the same page?
