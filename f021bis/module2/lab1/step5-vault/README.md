# Step 5 — a secret in Vault

**Slides:** Ansible recap — Vault · **~5 min**

A user `ops` on every node, with a password that must never be in Git in
clear. The convention: the encrypted file only defines `vault_*` variables;
a clear file maps each real name to its `vault_` twin, so `grep` still finds
where a variable comes from.

## The secret

`inventory/group_vars/all/` (next to `hosts.yml`, so that lab 3's
`ansible-playbook -i inventory ~/kubespray/cluster.yml` reads it too):

```sh
mkdir -p inventory/group_vars/all
EDITOR=nano ansible-vault create inventory/group_vars/all/vault.yml
```

One line in the editor: `vault_ops_password: <a password>`. No password is
asked: it comes from `~/.vault_pass` (`ansible.cfg`).

`inventory/group_vars/all/main.yml`, in clear:

```yaml
ops_password: "{{ vault_ops_password }}"
```

## The user

One more task in the role, with `ansible.builtin.user`: user `ops_user`,
shell `/bin/bash`, and

```yaml
    password: "{{ ops_password | password_hash('sha512', 'm2salt') }}"
```

The salt is fixed on purpose: try once without it (`password_hash('sha512')`),
run twice, and read the recaps.

```sh
ansible-playbook site.yml
ansible-playbook site.yml          # changed=0
ansible k8s_cluster -m ansible.builtin.command -a 'grep ^ops: /etc/shadow'
```

## What goes into Git

```sh
git add -A
git diff --staged                  # vault.yml: $ANSIBLE_VAULT;1.1;AES256 and hex, nothing else
git grep -n ops_password           # the clear name is findable; the value is not
ansible-vault view inventory/group_vars/all/vault.yml
git commit -m "user ops, password in Vault"
git tag lab1
```

## Questions

- Your pair partner clones `~/m2` on their machine. What do they need, that
  is not in the repo, to run `site.yml`? How would you hand it over?
- `ansible-playbook site.yml -e ops_password=other`: what happens, and
  why does `-e` win over the inventory? (The recap slide: *who wins?*)
