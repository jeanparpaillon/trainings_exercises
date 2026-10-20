# Step 3 — the inventory: `web`, `db`, `prod`

**Slides:** *Architecture, `ansible.cfg`, inventories* · **~5 min**

The file `ansible.cfg` points to: `~/m4/inventory`, in **INI** — the form
exam statements use. Write it yourself:

| Group | Members | How |
| --- | --- | --- |
| `web` | `node1`, `node2` | **one** line, a range |
| `db` | `node3` | |
| `prod` | the **groups** `web` and `db` | `[prod:children]` |

No `ansible_host=`: `node1`…`node3` resolve through the console's
`/etc/hosts` (`make -C lab0 up` wrote them there).

## Check

```sh
ansible-inventory --graph
ansible-inventory --list | less
ansible prod --list-hosts            # 3 hosts
ansible 'web:!node2' --list-hosts    # node1
ansible all -m ansible.builtin.ping  # no -i any more
```

The last one is lab 1's end state: green, with **no** `-i`, `-u`, `-k`,
`-b`. Now drop the `-i node1,node2,node3,` from `bootstrap.sh`: from here
on it uses this inventory too.

```sh
git add -A && git commit -m "inventory"
```

## Questions

- Which groups is `node3` in, counting the two Ansible always defines?
  Check with `ansible-inventory --graph`.
- You write `[prod]` instead of `[prod:children]`, the same two lines under
  it. What does `ansible prod --list-hosts` print, and why does `ping` on
  `prod` then fail?
