# Module 2 — the venv, Kubespray and the nodes, in the driver's console.
# From module2/:
#
#   make -C lab0 kubespray     ~/kubespray at KUBESPRAY_VERSION (read-only reference)
#   make -C lab0 venv          ~/.venvs/m2: Kubespray's requirements + the kubernetes client,
#                              kubernetes.core and ansible.posix into ~/.ansible/collections
#   make -C lab0 image         m2-node:latest (node/)
#   make -C lab0 up            node1…node3 at fixed IPs, names in /etc/hosts, your key in them
#   make -C lab0 down          delete the nodes and their volumes
#   make -C lab0 reset         down, then up: three blank nodes
#   make -C lab0 check         what is there
#
# Trainer:
#
#   make -C lab0 pull-consoles   kubespray venv image up, in every console (before session 1)
#   make -C lab0 predownload     in a console with lab 3a's inventory: Kubespray's
#                                binaries and images into the nodes (the day before session 4)

include ../versions.env

VENV          ?= $(HOME)/.venvs/m2
KUBESPRAY_DIR ?= $(HOME)/kubespray
COLLECTIONS   ?= $(HOME)/.ansible/collections
SSH_KEY       ?= $(HOME)/.ssh/id_ed25519
SSH_CONFIG    ?= $(HOME)/.ssh/config
HOSTS_FILE    ?= /etc/hosts
NODES         ?= node1 node2 node3
# 172.30.2.0/24 -> 172.30.2; node<i> is .1<i>
NODE_PREFIX   := $(shell echo $(NODE_SUBNET) | cut -d. -f1-3)

# Trainer side: the f021bis dev cluster's kubeconfig (shared-cluster/Makefile).
CONSOLES_KUBECONFIG ?= ../../../shared-cluster/kubeconfig
CONSOLES_KUBECTL := kubectl --kubeconfig=$(CONSOLES_KUBECONFIG) --context=training-f021bis -n consoles

kubespray:
	test -d $(KUBESPRAY_DIR) || git clone -q --depth 1 --branch $(KUBESPRAY_VERSION) \
	  https://github.com/kubernetes-sigs/kubespray.git $(KUBESPRAY_DIR)
	@test "$$(git -C $(KUBESPRAY_DIR) describe --tags)" = $(KUBESPRAY_VERSION) \
	  || { echo "$(KUBESPRAY_DIR) is not at $(KUBESPRAY_VERSION)"; exit 1; }

venv: kubespray
	test -x $(VENV)/bin/python || python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q --upgrade pip
	$(VENV)/bin/pip install -q -r $(KUBESPRAY_DIR)/requirements.txt \
	  kubernetes==$(PYTHON_KUBERNETES_VERSION)
	$(VENV)/bin/ansible-galaxy collection install -p $(COLLECTIONS) \
	  kubernetes.core:==$(KUBERNETES_CORE_VERSION) ansible.posix:==$(ANSIBLE_POSIX_VERSION)

image:
	docker build -q -t $(NODE_IMAGE) node

$(SSH_KEY):
	ssh-keygen -q -t ed25519 -N '' -f $@

# Like kind runs its nodes; plus an anonymous volume on /var, or containerd's
# overlayfs snapshotter fails on the dind overlay. Fixed IPs: Kubespray writes
# them into certificates and kubeconfigs.
up: $(SSH_KEY)
	docker network inspect $(NODE_NETWORK) >/dev/null 2>&1 \
	  || docker network create --subnet $(NODE_SUBNET) $(NODE_NETWORK) >/dev/null
	i=0; for n in $(NODES); do i=$$((i+1)); \
	  docker container inspect $$n >/dev/null 2>&1 && continue; \
	  docker run -d --name $$n --hostname $$n \
	    --network $(NODE_NETWORK) --ip $(NODE_PREFIX).1$$i \
	    --privileged --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
	    --cgroupns=private --tmpfs /run --tmpfs /tmp \
	    -v /lib/modules:/lib/modules:ro -v /var \
	    $(NODE_IMAGE) >/dev/null && echo "$$n $(NODE_PREFIX).1$$i"; \
	done
	for n in $(NODES); do \
	  until docker exec $$n systemctl is-active -q ssh 2>/dev/null; do sleep 1; done; \
	  docker exec -i $$n sh -c 'cat > /home/ansible/.ssh/authorized_keys \
	    && chown ansible: /home/ansible/.ssh/authorized_keys \
	    && chmod 0600 /home/ansible/.ssh/authorized_keys' < $(SSH_KEY).pub; \
	done
	@$(MAKE) -s hosts ssh-config

# The nodes' names, for the console: one block, rewritten in place.
hosts:
	@if [ -w $(HOSTS_FILE) ]; then \
	  { sed '/# BEGIN m2 nodes/,/# END m2 nodes/d' $(HOSTS_FILE); \
	    echo '# BEGIN m2 nodes'; \
	    i=0; for n in $(NODES); do i=$$((i+1)); echo "$(NODE_PREFIX).1$$i $$n"; done; \
	    echo '# END m2 nodes'; } > $(HOSTS_FILE).m2 \
	  && cat $(HOSTS_FILE).m2 > $(HOSTS_FILE) && rm -f $(HOSTS_FILE).m2; \
	else echo "$(HOSTS_FILE) not writable: node names not added"; fi

# `ssh node1`: user ansible, and no host key prompt — `reset` changes them.
ssh-config:
	@mkdir -p $(dir $(SSH_CONFIG)) && touch $(SSH_CONFIG) && chmod 0600 $(SSH_CONFIG)
	@grep -q '^# m2 nodes' $(SSH_CONFIG) || printf '%s\n' '# m2 nodes' \
	  'Host node? $(NODE_PREFIX).*' '  User ansible' '  IdentityFile $(SSH_KEY)' \
	  '  StrictHostKeyChecking no' '  UserKnownHostsFile /dev/null' '  LogLevel ERROR' \
	  >> $(SSH_CONFIG)

down:
	-docker rm -f -v $(NODES) >/dev/null 2>&1
	-docker network rm $(NODE_NETWORK) >/dev/null 2>&1

reset: down up

check:
	@ok() { printf '  %-28s %s\n' "$$1" "$$2"; }; \
	v=$$($(VENV)/bin/ansible --version 2>/dev/null | head -1); ok venv "$${v:-MISSING}"; \
	for c in kubernetes.core ansible.posix; do \
	  ok $$c "$$(ls -d $(COLLECTIONS)/ansible_collections/$${c%.*}/$${c#*.} >/dev/null 2>&1 \
	    && $(VENV)/bin/ansible-galaxy collection list $$c -p $(COLLECTIONS) 2>/dev/null | awk -v c=$$c '$$1==c{print $$2; exit}' || echo MISSING)"; \
	done; \
	ok kubespray "$$(git -C $(KUBESPRAY_DIR) describe --tags 2>/dev/null || echo MISSING)"; \
	for n in $(NODES); do ok $$n "$$(docker inspect -f '{{.State.Status}} {{(index .NetworkSettings.Networks "$(NODE_NETWORK)").IPAddress}}' $$n 2>/dev/null || echo MISSING)"; done; \
	ok 'ssh ansible@node1' "$$(ssh -F $(SSH_CONFIG) -o BatchMode=yes -o ConnectTimeout=5 ansible@$(NODE_PREFIX).11 'sudo -n true' 2>/dev/null && echo ok || echo FAILED)"

pull-consoles:
	for d in $$($(CONSOLES_KUBECTL) get deploy -o name); do \
	  echo "== $$d"; \
	  $(CONSOLES_KUBECTL) exec $$d -c console -- sh -c \
	    'cd ~/trainings_exercises && git pull -q --ff-only && make -s -C f021bis/module2/lab0 kubespray venv image up' & \
	done; wait

# Downloads only, with lab 3a's inventory (vault password: m2-solution).
# Run on blank nodes the day before session 4. (To validate: that the cache
# survives and that cluster.yml then skips the downloads.)
predownload:
	pass=$$(mktemp) && echo m2-solution > $$pass \
	 && cd ../lab3/solution-3a && $(VENV)/bin/ansible-playbook -i inventory \
	      --vault-password-file $$pass $(KUBESPRAY_DIR)/cluster.yml --tags download; \
	rc=$$?; rm -f $$pass; exit $$rc

.PHONY: kubespray venv image up hosts ssh-config down reset check pull-consoles predownload
