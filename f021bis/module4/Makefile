# Module 4 — catch-up targets: put ~/m4 in the state of the end of a lab,
# when yours is lost or hopelessly broken, and the nodes with it. Run from
# module4/, in your console. An existing ~/m4 is moved aside to ~/m4.<date>,
# never deleted.
#
#   make catch-up-lab1    ~/m4 = lab1/solution, tagged lab1; nodes bootstrapped
#                         (user ansible, your key, sudo) and step 4 run
#
# The nodes must be up (make -C lab0 up); they are not reset.

M4            ?= $(HOME)/m4
SSH_KEY       ?= $(HOME)/.ssh/id_ed25519
# lab0/node/Dockerfile
ROOT_PASSWORD  = redhat

# $(call solution,<dir>,<tag>): ~/m4 = <dir>, one commit, a tag.
define solution
	test ! -e $(M4) || mv $(M4) $(M4).$$(date +%Y%m%d-%H%M%S)
	cp -a $(1) $(M4)
	cd $(M4) && git init -q \
	  && { git config user.email >/dev/null || git config user.email m4@localhost; } \
	  && { git config user.name >/dev/null || git config user.name m4; } \
	  && git add -A && git commit -qm "$(2) (catch-up)" && git tag $(2)
endef

$(SSH_KEY):
	ssh-keygen -q -t ed25519 -N '' -f $@

catch-up-lab1: $(SSH_KEY)
	$(call solution,lab1/solution,lab1)
	cd $(M4) && ./bootstrap.sh -e ansible_password=$(ROOT_PASSWORD) && ./adhoc.sh

.PHONY: catch-up-lab1
