# Module 2 — catch-up targets: put ~/m2 in the state of the end of a lab,
# when yours is lost or hopelessly broken. Run from module2/, in the driver's
# console. An existing ~/m2 is moved aside to ~/m2.<date>, never deleted.
#
#   make catch-up-lab1    ~/m2 = lab1/solution, tagged lab1; site.yml run (nodes up)
#   make catch-up-lab3a   ~/m2 = lab3/solution-3a, tagged lab3a; the nodes are
#                         RECREATED blank (lab0 reset), then site.yml and
#                         Kubespray's cluster.yml: ~10 min with the downloads
#                         cached, 40+ without — and reset deletes the cache
#
# Lab 2 needs none: `iac` is rebuilt in its step 1, and lab2/solution/k8s/
# can be copied as is.

include versions.env

M2            ?= $(HOME)/m2
VENV          ?= $(HOME)/.venvs/m2
VAULT_PASS    ?= $(HOME)/.vault_pass
KUBESPRAY_DIR ?= $(HOME)/kubespray
# The solutions' vault files are encrypted with this; catch-up re-keys them to
# yours, so that the next labs run with your ~/.vault_pass.
SOLUTION_VAULT_PASS = m2-solution

export PATH := $(VENV)/bin:$(PATH)

# $(call solution,<dir>,<tag>): ~/m2 = <dir>, vaults re-keyed, one commit, a tag.
define solution
	test -f $(VAULT_PASS) || (umask 077; head -c 24 /dev/urandom | base64 > $(VAULT_PASS))
	test ! -e $(M2) || mv $(M2) $(M2).$$(date +%Y%m%d-%H%M%S)
	cp -a $(1) $(M2)
	cd $(M2) && pass=$$(mktemp) && echo $(SOLUTION_VAULT_PASS) > $$pass \
	  && grep -rl --include='*.yml' '^\$$ANSIBLE_VAULT' . \
	     | xargs ansible-vault rekey --vault-password-file $$pass \
	         --new-vault-password-file $(VAULT_PASS); \
	  rc=$$?; rm -f $$pass; exit $$rc
	cd $(M2) && git init -q \
	  && { git config user.email >/dev/null || git config user.email m2@localhost; } \
	  && { git config user.name >/dev/null || git config user.name m2; } \
	  && git add -A && git commit -qm "$(2) (catch-up)" && git tag $(2)
endef

catch-up-lab1:
	$(call solution,lab1/solution,lab1)
	cd $(M2) && ansible-playbook site.yml

catch-up-lab3a:
	$(MAKE) -C lab0 reset
	$(call solution,lab3/solution-3a,lab3a)
	cd $(M2) && ansible-playbook site.yml \
	  && ansible-playbook -i inventory $(KUBESPRAY_DIR)/cluster.yml

.PHONY: catch-up-lab1 catch-up-lab3a
