# m2-node: a kind-like node WITHOUT Kubernetes. Kubespray installs containerd,
# the kubelet and etcd itself (lab 3); lab 1's role prepares it before that.
#
#   make -C lab0 image
FROM ubuntu:24.04

ENV container=docker
STOPSIGNAL SIGRTMIN+3

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus openssh-server python3 sudo \
      iproute2 iputils-ping iptables kmod ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 # A container has no consoles, and nothing to set the clock of.
 && systemctl mask getty@tty1.service console-getty.service systemd-timesyncd.service \
 && systemctl enable ssh \
 # Empty: generated at each start (entrypoint), unique per node.
 && rm -f /etc/machine-id /var/lib/dbus/machine-id && touch /etc/machine-id \
 # The user Ansible connects as: key only (lab0 up installs it), sudo without
 # password. A locked password ("!") still allows keys: sshd uses PAM.
 && useradd -m -s /bin/bash ansible && passwd -l ansible >/dev/null \
 && echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible \
 && chmod 0440 /etc/sudoers.d/ansible \
 && install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh

COPY entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/sbin/init"]
