# Step 1 — install the web server on `web`

**Slides:** *Playbook structure and execution order* · **~5 min**

Lab 1's ad-hoc commands become a playbook: `~/m4/web.yml`, **one** play on
the group `web`. Each step of this lab adds a task (or a handler) to it.

Write the play yourself:

- a `name:` on the play and on **every** task — the output is the only log
  you have, and exam graders read it;
- `hosts: web`;
- no `become:` — `ansible.cfg` already has it;
- one task: package `nginx` present, with `ansible.builtin.dnf`.

```sh
ansible-doc -s ansible.builtin.dnf
```

## Before running anything

Three checks that touch no host — run them before **every** first run, here
and in the exam:

```sh
ansible-playbook web.yml --syntax-check
ansible-playbook web.yml --list-hosts      # node1, node2
ansible-playbook web.yml --list-tasks
```

Then:

```sh
ansible-playbook web.yml
ansible web -m ansible.builtin.command -a 'rpm -q nginx'
git add -A && git commit -m "web.yml: nginx"
```

## Questions

- The recap shows `ok=2` for one task. Which is the other one?
- Indent the task one level too far (or too little). What does
  `--syntax-check` say?
