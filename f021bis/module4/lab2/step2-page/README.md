# Step 2 — a page with the host name in it

**Slides:** *Facts, variables, `when`, `loop`, handlers* · **~10 min**

Each web server serves a page that says **which host** it is:
`/usr/share/nginx/html/index.html`, containing `Hello from <host>` and a
newline, where `<host>` is the host's name **in the inventory**.

- `ansible.builtin.copy` with `content:` (no file to write on your side);
- the host name is a **magic variable**, defined by Ansible for every host
  from the inventory (not a fact: no `setup` needed). Which one? List
  what a host has with
  `ansible node1 -m ansible.builtin.debug -a 'var=hostvars.node1' | less`;
- `mode: "0644"`, quoted: unquoted `0644` is an octal number to YAML, and a
  bare `644` is not what you think.

## Check

nginx is not running yet (step 4): read the file on the hosts.

```sh
ansible-playbook web.yml
ansible web -m ansible.builtin.command -a 'cat /usr/share/nginx/html/index.html'
git add -A && git commit -m "web.yml: page"
```

## Questions

- `inventory_hostname` vs `ansible_facts['hostname']`: here they are equal.
  When would they differ?
- You write the same page with
  `ansible.builtin.shell: echo "Hello from {{ inventory_hostname }}" > /usr/share/nginx/html/index.html`.
  What does the second run report, and why does it matter for the
  exam's grading run?
