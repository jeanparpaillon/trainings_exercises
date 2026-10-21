# Step 3 — configure to a state

**Slides:** *Step 3* · **~30 min** (5 theory, 25 exercise), alone ·
EX407: *use Ansible playbooks to configure systems to a specified state*

One playbook for the whole project, `site.yml`, that says what each host
should **be**: httpd on `web` (step 2's `web.yml`, reused as is), MariaDB on
`db`, users everywhere — the users described **once**, as data.

| | What | ~ |
| --- | --- | --- |
| 1 | `site.yml`: imports `web.yml` | 5 min |
| 2 | `db`: `mariadb-server` started, enabled | 5 min |
| 3 | users from `group_vars/all.yml`, `loop` | 10 min |
| 4 | one user on `web` only, `when` | 5 min |

Run twice, check, commit, tag `step3`.

**Start**: step 2's end state. If not: `make catch-up-step2`.

## 1 — `site.yml`

Its first line imports step 2's playbook: `- import_playbook: web.yml`.
Nothing is copied: `web.yml` stays usable alone.

## 2 — the database

A second play, on `db`: package `mariadb-server` present, service
`mariadb` started and enabled. (Package and service do not have the same
name: `rpm -ql mariadb-server | grep '\.service$'` on the node, or
`ansible db -m command -a 'systemctl list-unit-files mariadb*'`.)

## 3 — users, as data

`~/m4/group_vars/all.yml` — every host sees it — holds a variable
`m4_users`, a **list of dictionaries**:

| `name` | `groups` |
| --- | --- |
| `alice` | `wheel` |
| `bob` | *(none: `""`)* |

A third play, on `all`, with **one** `user` task and `loop:` over that
list; each element is `item`, its fields `item.name`, `item.groups`.

```sh
ansible node3 -m debug -a var=m4_users     # the variable, as node3 sees it
```

## 4 — one user on `web` only

In the same play, a task that creates `webadmin`, only on the hosts in the
group `web`: `when:` and the magic variable `group_names` (the groups of
the current host). `when:` takes an expression **without** `{{ }}`.

## Check

```sh
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml
ansible-playbook site.yml                              # changed=0 everywhere
ansible db -m command -a 'systemctl is-active mariadb'
ansible all -m command -a 'id alice'                   # in wheel
ansible all -m command -a 'id webadmin'                # node3 fails: right
git add -A && git commit -m "step 3" && git tag step3
```

On the second run, `node3` shows `skipping` for the `webadmin` task: that
is the `when`.

End state (start of step 4): `~/m4` tagged `step3`, with `site.yml` and
`group_vars/all.yml`; MariaDB running and enabled on `node3`; `alice` (in
`wheel`) and `bob` on every node, `webadmin` on `node1` and `node2`. From
nothing: `make catch-up-step3`.

## Questions

- Put `m4_users` in `site.yml`'s play `vars:` with only `alice`, keeping
  `group_vars/all.yml`. Which list wins? Then `-e '{"m4_users": []}'`?
  (Put it back.)
- Remove `bob` from the list and run again. Is `bob` gone from the hosts?
  What would you write to make sure he is?
- `when: "{{ 'web' in group_names }}"` works too, with a warning. Why the
  warning?
