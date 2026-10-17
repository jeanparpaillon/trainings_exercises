# Step 2 — facts: what a node in a container shares with its host

**Slides:** Where the labs run · **~10 min**

Kubespray decides a lot from facts: how much memory, which kernel, is there
swap. Before it reads them in lab 3, read them yourself — and compare with
what you know about the machine.

## The facts

```sh
ansible all -m ansible.builtin.setup -a 'filter=ansible_kernel,ansible_memtotal_mb,ansible_processor_vcpus,ansible_swaptotal_mb,ansible_virtualization_type'
```

The same, from the console (itself a container on the server):

```sh
uname -r
free -m
nproc
```

And the loaded kernel modules, in a node and in the console:

```sh
diff <(ssh ansible@node1 cut -d' ' -f1 /proc/modules | sort) \
     <(cut -d' ' -f1 /proc/modules | sort) && echo same modules
```

Then what is per node — compare these across `node1` and `node2`:

```sh
ansible all -m ansible.builtin.command -a 'hostname -I'
ansible all -m ansible.builtin.command -a 'cat /etc/hostname'
```

## Questions

Write the answers down; they are the debrief of the session.

- What do the three nodes share with each other, and with the server? What
  is really each node's own?
- Kubernetes' node prerequisites are: no swap, kernel modules loaded,
  sysctls set (`net.*`, but also `vm.*`, `kernel.*`, `fs.*` — Kubespray sets
  some of each). Which of these are **per node** here, and which would a
  playbook run on `node1` change for every node of the room?
- Kubespray runs `swapoff -a` when `ansible_swaptotal_mb` is not 0. Where
  would that run, and what would it switch off?
- On VMs, would any of your answers change?

No commit: nothing changed.
