# Step 5 — users from a list, with `loop`

**Slides:** *Facts, variables, `when`, `loop`, handlers* · **~5 min**

The web servers need two accounts. Describe them **once**, as data, in the
play's `vars:`:

| `name` | `shell` |
| --- | --- |
| `alice` | `/bin/bash` |
| `bob` | `/bin/sh` |

- the variable is `web_users`, a **list of dictionaries** with the keys
  `name` and `shell`;
- **one** `ansible.builtin.user` task with `loop:` over it; each element is
  `item`, its fields `item.name`, `item.shell`.

## Check

```sh
ansible-playbook web.yml            # one result line per user and host
ansible web -m ansible.builtin.command -a 'getent passwd alice bob'
git add -A && git commit -m "web.yml: users"
```

## Questions

- Add `carol` (`/bin/bash`) to the list and run again: which items report
  `changed`?
- Remove `bob` from the list and run again. Is `bob` gone from the hosts?
  What would you write to make sure he is?
