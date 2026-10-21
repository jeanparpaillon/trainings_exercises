# Step 6 — Vault

**Slides:** *Step 6* · **~30 min** (5 theory, 25 exercise), alone ·
EX407: *use Ansible Vault in playbooks to protect sensitive data*

A protected directory on the web servers, `/private/`, behind an HTTP
password. The password is in the project — **encrypted**: never in clear
in Git, never in the output.

| | What | ~ |
| --- | --- | --- |
| 1 | `group_vars/web/`: `vars.yml`, `vault.yml` | 5 min |
| 2 | role: `.htpasswd`, `private/.htaccess` | 10 min |
| 3 | snippet: `AllowOverride AuthConfig` | 5 min |
| 4 | `~/.vault_pass`, `.gitignore`, `ansible.cfg` | 5 min |

Commit, tag `step6`.

**Start**: step 5's end state. If not: `make catch-up-step5`.

Values to use — the catch-up and the checks expect them:

| | |
| --- | --- |
| user | `m4` |
| its password | `S3cr3t!` |
| vault password | `m4vault` |

## 1 — the vars / vault pair

`group_vars/web.yml` becomes a **directory**, `group_vars/web/` (a file and
a directory of the same name conflict: `git mv group_vars/web.yml
group_vars/web/vars.yml`):

- `vars.yml`, in clear: `web_title`, and
  `web_auth_password: "{{ vault_web_auth_password }}"`;
- `vault.yml`, **encrypted**: `vault_web_auth_password: S3cr3t!`.

```sh
ansible-vault create group_vars/web/vault.yml       # asks the vault password
ansible-vault view group_vars/web/vault.yml
head -1 group_vars/web/vault.yml                    # $ANSIBLE_VAULT;1.1;AES256
```

`git grep vault_web_auth_password` finds where the secret is **used**,
without decrypting anything: that is the point of the pair.

## 2 — the protected directory, in the role

Tasks in `roles/httpd/tasks/main.yml`:

1. directory `/var/www/html/private`, and an `index.html` in it;
2. `/var/www/html/private/.htaccess`, mode `0644`:

   ```apache
   AuthType Basic
   AuthName "m4 private"
   AuthUserFile /etc/httpd/.htpasswd
   Require valid-user
   ```

3. `/etc/httpd/.htpasswd`: **one line**, `m4:<hash of the password>`, owner
   `root`, group `apache`, mode `0640`, written with `copy` and `content:`.
   The hash: `{{ web_auth_password | password_hash('sha512', web_auth_salt) }}`,
   with `web_auth_salt` (`m4salt`) and `web_auth_user` (`m4`) in the role's
   `defaults/`. **`no_log: true`** on that task.

Why a fixed salt: `password_hash` picks a random one otherwise, so the hash
— and the task — would change on every run. Why not the `htpasswd`
module: it needs `passlib` on the managed node, which Rocky 9 does not
ship; httpd on Linux reads the SHA-512 crypt hash `password_hash` makes.

```sh
ansible-playbook site.yml --ask-vault-pass
```

## 3 — let httpd read `.htaccess`

httpd ignores `.htaccess` files by default (`AllowOverride None`): without
this, `/private/` is open. In the step 4 snippet,
`roles/httpd/templates/m4.conf.j2`:

```apache
<Directory "/var/www/html/private">
    AllowOverride AuthConfig
</Directory>
```

The snippet changed: the handler restarts httpd — step 4's mechanics at
work.

## 4 — no more prompt, no secret in Git

```sh
(umask 077; echo m4vault > ~/.vault_pass)     # outside the repo, mode 600
```

`ansible.cfg`, `[defaults]`: `vault_password_file = ~/.vault_pass`. And a
`.gitignore` with `.vault_pass`, in case one ever lands in the repo.

## Check

```sh
ansible-playbook site.yml                       # no prompt
ansible-playbook site.yml                       # changed=0
curl -s -o /dev/null -w '%{http_code}\n' http://node1/private/            # 401
curl -u m4:'S3cr3t!' http://node1/private/                                # the page
curl -s -o /dev/null -w '%{http_code}\n' -u m4:wrong http://node2/private/ # 401
git grep 'S3cr3t'                               # nothing
ansible-playbook site.yml -v | grep -c 'S3cr3t' # 0: no_log
git add -A && git commit -m "step 6" && git tag step6
```

End state — the end of the module: `~/m4` tagged `step6`; `/private/` on
`node1` and `node2` asks for `m4` / `S3cr3t!`. From nothing:
`make catch-up-step6` (it also writes `~/.vault_pass`, moving a different
one aside).

## Questions

- Remove `no_log: true` and run with `-v` after changing the salt. What
  does the output show?
- `ansible-vault rekey group_vars/web/vault.yml`: what changes in the file,
  and what do you have to change elsewhere?
- `curl` gives **403**, not 401: which file can httpd not read? (`ls -l`
  on the node, and the `apache` user.)
