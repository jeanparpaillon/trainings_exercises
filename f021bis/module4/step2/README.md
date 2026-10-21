# Step 2 — first playbook

**Slides:** *Step 2* · **~25 min** (5 theory, 20 exercise), alone ·
EX407: *create Ansible playbooks*

Step 1's ad-hoc commands become a playbook: `~/m4/web.yml`, **one** play on
the group `web` that installs httpd, opens HTTP in the firewall, and starts
the service — and does nothing on its second run.

| | What | ~ |
| --- | --- | --- |
| 1 | `web.yml`: package `httpd` | 5 min |
| 2 | firewalld: `http`, permanent + immediate | 5 min |
| 3 | `httpd` started and enabled | 5 min |
| 4 | run twice, check, commit, tag `step2` | 5 min |

**Start**: step 1's end state — `ansible all -m ping` green with no option.
If not: `make catch-up-step1` in `module4/`.

## 1 — the play, the package

Write the play yourself:

- a `name:` on the play and on **every** task — the output is the only log
  you have, and exam graders read it;
- `hosts: web`;
- no `become:` — `ansible.cfg` already has it;
- one task: package `httpd` present.

```sh
ansible-doc -s package
```

Three checks that touch no host — before **every** first run, here and in
the exam:

```sh
ansible-playbook web.yml --syntax-check
ansible-playbook web.yml --list-hosts      # node1, node2
ansible-playbook web.yml --list-tasks
ansible-playbook web.yml
```

## 2 — the firewall

The nodes run **firewalld**, which blocks HTTP:

```sh
ansible web -m command -a 'firewall-cmd --list-services'
```

A task: the firewalld **service** `http` enabled, both **permanently**
(survives a reload or a reboot) and **now** — two options of one module.

```sh
ansible-doc -l | grep -i firewall
```

## 3 — the service

A task: `httpd` started **and** enabled at boot — one module, two options.

## 4 — run twice, check

```sh
ansible-playbook web.yml
ansible-playbook web.yml          # PLAY RECAP: changed=0 on node1 and node2
curl http://node1                 # Rocky's "HTTP Server Test Page"
curl http://node2
curl http://node3                 # refused: not in web, firewall closed
ansible web -m command -a 'systemctl is-enabled httpd'
git add -A && git commit -m "step 2" && git tag step2
```

The test page comes with HTTP status **403** (`curl -I`): there is no
`index.html` yet, and Rocky's httpd shows that page instead. Step 4
deploys one.

End state (start of step 3): `~/m4` tagged `step2`, with `web.yml`; httpd
installed, running and enabled on `node1` and `node2`, HTTP open. From
nothing: `make catch-up-step2`.

## Questions

- The recap shows `ok=4` for three tasks. Which is the fourth?
- `permanent: true` without `immediate: true`: what would `curl` do right
  after the run, and after `firewall-cmd --reload`?
- Indent a task one level too far. What does `--syntax-check` say?
