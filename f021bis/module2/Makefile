# Module 2 — catch-up targets: put ~/m2 in the state of the end of a lab,
# when yours is lost or hopelessly broken. Run from module2/, in the driver's
# console, nodes up (make -C lab0 up). An existing ~/m2 is moved aside to
# ~/m2.<date>, never deleted.
#
#   make catch-up-lab1   ~/m2 = lab1/solution, a repo tagged lab1, site.yml run
#
# catch-up-lab3a is not written yet (lab 3).

include versions.env

M2         ?= $(HOME)/m2
VENV       ?= $(HOME)/.venvs/m2
VAULT_PASS ?= $(HOME)/.vault_pass
# lab1/solution's vault.yml is encrypted with this; catch-up re-keys it to
# yours, so that the next labs run with your ~/.vault_pass.
SOLUTION_VAULT_PASS = m2-solution

export PATH := $(VENV)/bin:$(PATH)

catch-up-lab1:
	test -f $(VAULT_PASS) || (umask 077; head -c 24 /dev/urandom | base64 > $(VAULT_PASS))
	test ! -e $(M2) || mv $(M2) $(M2).$$(date +%Y%m%d-%H%M%S)
	cp -a lab1/solution $(M2)
	cd $(M2) && pass=$$(mktemp) && echo $(SOLUTION_VAULT_PASS) > $$pass \
	  && ansible-vault rekey --vault-password-file $$pass \
	       --new-vault-password-file $(VAULT_PASS) inventory/group_vars/all/vault.yml; \
	  rc=$$?; rm -f $$pass; exit $$rc
	cd $(M2) && git init -q \
	  && { git config user.email >/dev/null || git config user.email m2@localhost; } \
	  && { git config user.name >/dev/null || git config user.name m2; } \
	  && git add -A && git commit -qm "lab1 (catch-up)" && git tag lab1
	cd $(M2) && ansible-playbook site.yml

.PHONY: catch-up-lab1
