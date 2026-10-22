# Module 4 — the environment (step 0) and the catch-up targets. Run from
# module4/, in your console.
#
#   make venv              ~/.venv/m4: Ansible ANSIBLE_VERSION (versions.env), on
#                          a Python PYTHON_VERSION that uv fetches into ~/.local
#   make image             m4-node:latest (lab0/node/)
#   make up                node1…node3 in the exam's initial state (root/redhat)
#   make reset             down, then up: back to the initial state
#   make down | check      see lab0/Makefile
#
#   make catch-up-stepN    ~/m4 = stepN/solution, tagged stepN, and the nodes
#                          brought to the end of step N (N = 1…6)
#
# Trainer:
#
#   make pull-consoles     in every console: module 2's nodes down, venv, image, up
#   make reset-consoles    in every console: make reset (~/m4 untouched)
#
# catch-up: an existing ~/m4 is moved aside to ~/m4.<date>, never deleted. The
# nodes must be up; they are not reset — each target replays the whole chain
# from the bootstrap with root's password, so it works on blank nodes too.

include versions.env

VENV     ?= $(HOME)/.venv/m4
UV       ?= $(HOME)/.local/bin/uv
M4       ?= $(HOME)/m4
SSH_KEY  ?= $(HOME)/.ssh/id_ed25519
# lab0/node/Dockerfile
ROOT_PASSWORD   = redhat
# step6/README.md: the password of step6/solution/group_vars/web/vault.yml
VAULT_PASS     ?= $(HOME)/.vault_pass
VAULT_PASSWORD  = m4vault

# The venv's ansible first, activated or not.
export PATH := $(VENV)/bin:$(PATH)

UV_TGZ = uv-x86_64-unknown-linux-gnu.tar.gz
UV_URL = https://github.com/astral-sh/uv/releases/download/$(UV_VERSION)/$(UV_TGZ)

$(UV):
	mkdir -p $(dir $@)
	t=$$(mktemp -d) && cd $$t \
	  && curl -fsSLO $(UV_URL) && curl -fsSLO $(UV_URL).sha256 \
	  && sha256sum -c $(UV_TGZ).sha256 \
	  && tar -xzf $(UV_TGZ) --strip-components=1 -C $(dir $@) \
	       uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx \
	  && cd / && rm -rf $$t

venv: $(UV)
	$(UV) python install -q $(PYTHON_VERSION)
	test -x $(VENV)/bin/python || $(UV) venv -q -p $(PYTHON_VERSION) $(VENV)
	VIRTUAL_ENV=$(VENV) $(UV) pip install -q \
	  ansible==$(ANSIBLE_VERSION) jinja2==$(JINJA2_VERSION) \
	  markupsafe==$(MARKUPSAFE_VERSION) setuptools==$(SETUPTOOLS_VERSION) \
	  cryptography==$(CRYPTOGRAPHY_VERSION)
	@$(VENV)/bin/ansible --version | head -1

image up down reset check:
	@$(MAKE) -s -C lab0 $@

pull-consoles reset-consoles:
	$(MAKE) -C lab0 $@

# $(call solution,<dir>,<tag>): ~/m4 = <dir>, one commit, a tag.
define solution
	test ! -e $(M4) || mv $(M4) $(M4).$$(date +%Y%m%d-%H%M%S)
	cp -r $(1) $(M4)
	cd $(M4) && git init -q \
	  && { git config user.email >/dev/null || git config user.email m4@localhost; } \
	  && { git config user.name >/dev/null || git config user.name m4; } \
	  && git add -A && git commit -qm "$(2) (catch-up)" && git tag $(2)
endef

BOOTSTRAP = ./bootstrap.sh -e ansible_password=$(ROOT_PASSWORD)

$(SSH_KEY):
	ssh-keygen -q -t ed25519 -N '' -f $@

# Step 6's vault password, unless ~/.vault_pass already holds it; another
# one is moved aside, as ~/m4 is.
vault-pass:
	if [ -e $(VAULT_PASS) ] && [ "$$(cat $(VAULT_PASS))" != $(VAULT_PASSWORD) ]; then \
	  mv $(VAULT_PASS) $(VAULT_PASS).$$(date +%Y%m%d-%H%M%S); fi
	[ -e $(VAULT_PASS) ] || (umask 077; echo $(VAULT_PASSWORD) > $(VAULT_PASS))

catch-up-step1: $(SSH_KEY)
	$(call solution,step1/solution,step1)
	cd $(M4) && $(BOOTSTRAP)

catch-up-step2: $(SSH_KEY)
	$(call solution,step2/solution,step2)
	cd $(M4) && $(BOOTSTRAP) && ansible-playbook web.yml

catch-up-step3 catch-up-step4 catch-up-step5: catch-up-step%: $(SSH_KEY)
	$(call solution,step$*/solution,step$*)
	cd $(M4) && $(BOOTSTRAP) && ansible-playbook site.yml

catch-up-step6: $(SSH_KEY) vault-pass
	$(call solution,step6/solution,step6)
	cd $(M4) && $(BOOTSTRAP) && ansible-playbook site.yml

.PHONY: venv image up down reset check pull-consoles reset-consoles vault-pass \
	catch-up-step1 catch-up-step2 catch-up-step3 catch-up-step4 catch-up-step5 catch-up-step6
