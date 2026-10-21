# m4-node: a Rocky Linux 9 managed host in the EXAM's initial state — root
# with a password over SSH, nothing else. No `ansible` user, no key, no sudo
# rule: step 1 is that bootstrap. httpd and MariaDB are not installed
# either; steps 2 and 3 do it, from the RPMs already in dnf's cache.
#
#   make -C lab0 image
FROM rockylinux/rockylinux:9

ENV container=docker
STOPSIGNAL SIGRTMIN+3

RUN dnf -y install --setopt=install_weak_deps=False \
      systemd openssh-server openssh-clients python3 sudo \
      firewalld policycoreutils procps-ng iproute hostname less \
 && dnf clean all \
 # A container has no consoles, no udev, nothing to set the clock of, and
 # systemd-logind needs what a container does not have; masked so that
 # `systemctl is-system-running` says `running`, not `degraded`.
 && systemctl mask getty@tty1.service console-getty.service serial-getty@.service \
      systemd-udevd.service systemd-udev-trigger.service systemd-logind.service \
      systemd-remount-fs.service sys-kernel-debug.mount dev-hugepages.mount \
 && systemctl enable sshd firewalld \
 # Empty: generated at each boot, unique per node.
 && rm -f /etc/machine-id && touch /etc/machine-id \
 # Host keys too (sshd-keygen@.service makes them at first boot): reset gives
 # new ones, and lab0 up refreshes the console's known_hosts.
 && rm -f /etc/ssh/ssh_host_*key* \
 && echo redhat | passwd --stdin root >/dev/null

# Every package the steps install, downloaded now, with the repo
# metadata: `dnf install` on a node then needs no network. The mirrorlist
# picked dead mirrors on the dry run, and each node fetched ~111 MB of
# metadata after every reset; dl.rockylinux.org (Rocky's CDN-fronted origin)
# is kept for anything outside this list. metadata_expire=-1 keeps the baked
# metadata — rebuild the image before each course. Weak dependencies are
# downloaded too: Ansible's dnf module installs them (install_weak_deps
# defaults to true there, whatever dnf.conf says). tree: the become drill of
# step 1.
RUN sed -i -e 's/^mirrorlist=/#mirrorlist=/' \
      -e 's|^#baseurl=http://dl.rockylinux.org/|baseurl=https://dl.rockylinux.org/|' \
      /etc/yum.repos.d/rocky*.repo \
 && printf '%s\n' keepcache=True metadata_expire=-1 >> /etc/dnf/dnf.conf \
 && dnf -y install --downloadonly --setopt=install_weak_deps=True \
      httpd mariadb-server tree

# Read before sshd_config's own settings: for sshd the first value wins.
COPY sshd-m4.conf /etc/ssh/sshd_config.d/00-m4.conf
COPY chronyd.sysconfig /etc/sysconfig/chronyd

CMD ["/sbin/init"]
