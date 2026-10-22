# Module 4 — the managed hosts, in your console. From module4/ (whose
# Makefile wraps image, up, down, reset, check and pull-consoles):
#
#   make -C lab0 image         m4-node:latest (node/)
#   make -C lab0 up            node1…node3 at fixed IPs on network m4, their names in
#                              /etc/hosts, their host keys in ~/.ssh/known_hosts
#   make -C lab0 reset         down, then up: back to the INITIAL state (root + password
#                              `redhat` only) — before step 1, or step 5's check
#   make -C lab0 down          delete the nodes and the network
#   make -C lab0 check         what is there
#
# Trainer:
#
#   make -C lab0 pull-consoles   in every console: module 2's nodes down, then venv,
#                                image, up (the day before)
#   make -C lab0 reset-consoles  in every console: reset — every trainee's nodes back
#                                to root/redhat (before step 1, if they were used);
#                                ~/m4 is not touched
#
# Module 2's nodes have the same names: `up` refuses to start while they exist
# (`make -C ../../module2/lab0 down`), and removes module 2's /etc/hosts and
# ~/.ssh/config blocks, whose `User ansible` would hide a missing remote_user.

NODE_IMAGE   ?= m4-node:latest
NODE_NETWORK ?= m4
NODE_SUBNET  ?= 172.30.4.0/24
NODES        ?= node1 node2 node3
HOSTS_FILE   ?= /etc/hosts
KNOWN_HOSTS  ?= $(HOME)/.ssh/known_hosts
SSH_CONFIG   ?= $(HOME)/.ssh/config
# 172.30.4.0/24 -> 172.30.4; node<i> is .1<i>
NODE_PREFIX  := $(shell echo $(NODE_SUBNET) | cut -d. -f1-3)
# On every m4 node: what down deletes, and what up recognises as its own.
LABEL        := f021bis.module=m4

# Trainer side: the f021bis dev cluster's kubeconfig (shared-cluster/Makefile).
CONSOLES_KUBECONFIG ?= ../../shared-cluster/kubeconfig
CONSOLES_KUBECTL := kubectl --kubeconfig=$(CONSOLES_KUBECONFIG) --context=training-f021bis -n consoles

image:
	docker build -q -t $(NODE_IMAGE) node

# systemd as PID 1, run as module 2 runs its nodes (validated there, in dind).
# Fixed IPs: module 1 learned that restarted containers can swap them.
up:
	@for n in $(NODES); do \
	  l=$$(docker inspect -f '{{index .Config.Labels "f021bis.module"}}' $$n 2>/dev/null) || continue; \
	  [ "$$l" = m4 ] || { echo "$$n exists and is not an m4 node (module 2's?):" \
	    "make -C ../../module2/lab0 down"; exit 1; }; \
	done
	docker network inspect $(NODE_NETWORK) >/dev/null 2>&1 \
	  || docker network create --subnet $(NODE_SUBNET) $(NODE_NETWORK) >/dev/null
	i=0; for n in $(NODES); do i=$$((i+1)); \
	  docker container inspect $$n >/dev/null 2>&1 && continue; \
	  docker run -d --name $$n --hostname $$n --label $(LABEL) \
	    --network $(NODE_NETWORK) --ip $(NODE_PREFIX).1$$i \
	    --privileged --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
	    --cgroupns=private --tmpfs /run --tmpfs /tmp \
	    $(NODE_IMAGE) >/dev/null && echo "$$n $(NODE_PREFIX).1$$i"; \
	done
	for n in $(NODES); do \
	  until docker exec $$n systemctl is-active -q sshd 2>/dev/null; do \
	    [ "$$(docker inspect -f '{{.State.Running}}' $$n)" = true ] \
	      || { echo "$$n exited:"; docker logs --tail 20 $$n; exit 1; }; \
	    sleep 1; done; \
	done
	@$(MAKE) -s hosts known-hosts ssh-config

# The nodes' names, for the console: one block, rewritten in place (and
# module 2's, which maps the same names, dropped).
hosts:
	@if [ -w $(HOSTS_FILE) ]; then \
	  { sed -e '/# BEGIN m4 nodes/,/# END m4 nodes/d' \
	        -e '/# BEGIN m2 nodes/,/# END m2 nodes/d' $(HOSTS_FILE); \
	    echo '# BEGIN m4 nodes'; \
	    i=0; for n in $(NODES); do i=$$((i+1)); echo "$(NODE_PREFIX).1$$i $$n"; done; \
	    echo '# END m4 nodes'; } > $(HOSTS_FILE).m4 \
	  && cat $(HOSTS_FILE).m4 > $(HOSTS_FILE) && rm -f $(HOSTS_FILE).m4; \
	else echo "$(HOSTS_FILE) not writable: node names not added"; fi

# Every up makes new host keys: forget the old ones, record the new ones, so
# that `ssh root@node1` and `ansible -k` (sshpass cannot answer the host key
# prompt) work at once. Host key checking itself stays on, as on the exam.
known-hosts:
	@mkdir -p -m 0700 $(dir $(KNOWN_HOSTS)) && touch $(KNOWN_HOSTS)
	@i=0; for n in $(NODES); do i=$$((i+1)); \
	  ssh-keygen -q -R $$n -f $(KNOWN_HOSTS) >/dev/null 2>&1; \
	  ssh-keygen -q -R $(NODE_PREFIX).1$$i -f $(KNOWN_HOSTS) >/dev/null 2>&1; \
	  k=$$(ssh-keyscan $(NODE_PREFIX).1$$i 2>/dev/null) && [ -n "$$k" ] \
	    || { echo "$$n: ssh-keyscan failed"; continue; }; \
	  echo "$$k" | sed "s/^[^ ]*/$$n,$(NODE_PREFIX).1$$i/" >> $(KNOWN_HOSTS); \
	done; rm -f $(KNOWN_HOSTS).old

# Module 2's block (user ansible, no host key checking) does not belong here.
ssh-config:
	@if [ -f $(SSH_CONFIG) ] && grep -q '^# m2 nodes' $(SSH_CONFIG); then \
	  awk '/^# m2 nodes/{skip=2; next} skip==2 && /^Host /{skip=1; next} skip && /^[ \t]/{next} {skip=0; print}' \
	    $(SSH_CONFIG) > $(SSH_CONFIG).m4 && cat $(SSH_CONFIG).m4 > $(SSH_CONFIG) && rm -f $(SSH_CONFIG).m4 \
	  && echo "$(SSH_CONFIG): module 2's block removed"; \
	fi

down:
	-ids=$$(docker ps -aq --filter label=$(LABEL)); [ -z "$$ids" ] || docker rm -f -v $$ids >/dev/null
	-docker network rm $(NODE_NETWORK) >/dev/null 2>&1

reset: down up

check:
	@ok() { printf '  %-22s %s\n' "$$1" "$$2"; }; \
	ok ansible "$$(command -v ansible >/dev/null && ansible --version | head -1 || echo MISSING)"; \
	ok sshpass "$$(command -v sshpass || echo 'MISSING (ansible -k needs it)')"; \
	ok image "$$(docker image inspect -f '{{.Id}}' $(NODE_IMAGE) 2>/dev/null | cut -c8-19 || echo MISSING)"; \
	for n in $(NODES); do \
	  s=$$(docker inspect -f '{{.State.Status}} {{(index .NetworkSettings.Networks "$(NODE_NETWORK)").IPAddress}}' $$n 2>/dev/null) \
	    || { ok $$n MISSING; continue; }; \
	  s="$$s systemd=$$(docker exec $$n systemctl is-system-running 2>/dev/null)"; \
	  ok $$n "$$s firewalld=$$(docker exec $$n firewall-cmd --state 2>/dev/null || echo down)"; \
	done; \
	ok 'node1 in /etc/hosts' "$$(getent hosts node1 || echo MISSING)"; \
	ok 'ssh root@node1' "$$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o PreferredAuthentications=none \
	  -o UserKnownHostsFile=$(KNOWN_HOSTS) root@$(NODE_PREFIX).11 true 2>&1 \
	  | grep -q 'Permission denied (.*password' && echo 'password login offered' || echo FAILED)"; \
	ok 'dnf cache on node1' "$$(docker exec node1 dnf -C -q repoquery httpd 2>/dev/null | grep -q httpd && echo ok || echo MISSING)"; \
	ok 'dl.rockylinux.org' "$$(docker exec node1 curl -sf -m 10 -o /dev/null https://dl.rockylinux.org/pub/rocky/9/ \
	  && echo 'reachable (only for packages outside the cache)' || echo 'unreachable (fine: the labs use the cache)')"

pull-consoles:
	for d in $$($(CONSOLES_KUBECTL) get deploy -o name); do \
	  echo "== $$d"; \
	  $(CONSOLES_KUBECTL) exec $$d -c console -- sh -c \
	    'cd ~/trainings_exercises && git pull -q --ff-only \
	     && make -s -C f021bis/module2/lab0 down \
	     && make -s -C f021bis/module4 venv image up' & \
	done; wait

# One line per console, prefixed with its name: they run in parallel.
reset-consoles:
	for d in $$($(CONSOLES_KUBECTL) get deploy -o name); do \
	  $(CONSOLES_KUBECTL) exec $$d -c console -- sh -c \
	    'make -s -C ~/trainings_exercises/f021bis/module4/lab0 reset' 2>&1 \
	    | sed "s|^|$${d#*/}: |" & \
	done; wait

.PHONY: image up hosts known-hosts ssh-config down reset check pull-consoles reset-consoles
