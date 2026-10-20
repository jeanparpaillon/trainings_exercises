# Step 2 — bootstrap the user `ansible`: key, sudo

**Slides:** *SSH and ad-hoc commands* · **~10 min**

The nodes start the way exam hosts do: **root, with a password**
(`redhat`), nothing else. Ansible will connect as `ansible`, with a key,
and become root with sudo — that user does not exist yet. Create it with
Ansible itself, **ad hoc**, connecting as root with root's password. Exam
task 2 is this step, with another user name.

## A key

```sh
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
```

## As root, with root's password

There is no inventory yet (step 3): give the hosts on the command line,
`-i node1,node2,node3,` (the trailing comma makes it a list, not a file
name). Root's password: `-u root -k`. `become = true` in `ansible.cfg` is
harmless here — root can sudo to root.

```sh
ansible all -i node1,node2,node3, -u root -k -m ansible.builtin.ping
```

`-k` needs `sshpass` in the console. If `ping` fails with *Host key
checking is enabled* or *to use the 'ssh' connection type with passwords*,
see *Troubleshooting* below.

Now, one ad-hoc command each, with the same `-i … -u root -k`:

1. user `ansible`, in the supplementary group `wheel` (without removing
   it from any other);
2. your **public** key in its `authorized_keys`;
3. `/etc/sudoers.d/ansible`: `ansible` may run anything as anyone, without
   a password. A broken sudoers file locks sudo for **everyone**: have the
   module check the file with `visudo -cf %s` **before** putting it in
   place, and give it mode `0440`.

Find the modules and their options yourself:

```sh
ansible-doc -l | grep -iE 'user|authorized'
ansible-doc -s ansible.builtin.user          # a task skeleton
ansible-doc ansible.posix.authorized_key     # the full page, with EXAMPLES
ansible-doc ansible.builtin.copy             # content=, validate=
```

For the key, read the file on the **control node** with a lookup:
`"{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"`. Mind the quoting: the
whole `-a` in double quotes, the lookup's arguments in single.

Keep the three commands in `~/m4/bootstrap.sh`: lab 4 resets the nodes and
asks you to bootstrap them again, and the exam starts with the same three.

## Check

```sh
ssh ansible@node1 'id; sudo -n true && echo sudo ok'     # no password asked
ansible all -i node1,node2,node3, -m ansible.builtin.ping # no -u, no -k
ansible all -i node1,node2,node3, -m ansible.builtin.command -a 'whoami'
```

`whoami` says `root`: you connect as `ansible` (`remote_user`), and the
module runs as root (`become`).

Run `./bootstrap.sh` a second time: every task `ok`, nothing `changed`.

```sh
git add -A && git commit -m "bootstrap"
```

## Questions

- Your key went into `authorized_keys`. Where did the *private* key go?
- `wheel` on Rocky already grants sudo (`%wheel ALL=(ALL) ALL` in
  `/etc/sudoers`). Why is it not enough for Ansible here?
- Without `validate=`, what happens to `sudo` on a host where you wrote
  `NOPASSWD ALL` (missing colon), and how would you repair it?

## Troubleshooting

| Message | Cause |
| --- | --- |
| `to use the 'ssh' connection type with passwords … you must install the sshpass program` | no `sshpass` in the console: it is in console image `f021bis-console:3` — ask the trainer |
| `Using a SSH password instead of a key is not possible because Host Key checking is enabled` | the node's host key is not in `~/.ssh/known_hosts` (sshpass cannot answer the prompt): `make -C ~/trainings_exercises/f021bis/module4/lab0 known-hosts` |
| `Permission denied (publickey,…)` on `ssh ansible@node1` | the key is not in `/home/ansible/.ssh/authorized_keys`, or it is the wrong one: `ansible node1 -i node1, -u root -k -m command -a 'cat /home/ansible/.ssh/authorized_keys'` |
| `sudo: a password is required` | the sudoers file is missing or not applied: `ansible node1 -i node1, -u root -k -m command -a 'visudo -c'` |
