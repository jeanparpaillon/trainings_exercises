# Module 3 — chart, images and Zabbix credentials, in your console.
# From module3/:
#
#   make -C lab0 chart         the Zabbix and podinfo charts as lab0/charts/<chart>-<version>.tgz
#   make -C lab0 pull          the images of the module into your Docker
#   make -C lab0 load          …and into the nodes of $(CLUSTER) (lab 1 step 1)
#   make -C lab0 credentials   ~/.zabbix/user.env and ~/.zabbix/user.psk, from
#                              Secret zabbix-user on the shared cluster
#   make -C lab0 check         what is there, and whether the server answers
#
# Trainer, from module3/ on the trainer's machine, after `make zabbix-users`
# in shared-cluster/:
#
#   make -C lab0 pull-consoles   git pull, chart and pull in every console

include ../versions.env

SHELL := /bin/bash

# Where the console finds its Secret: the context console-init creates, whose
# namespace is the trainee's.
SECRET_CONTEXT ?= training-f021bis
ZBX_DIR        ?= $(HOME)/.zabbix
# The API as the console reaches it. Not the URL of the Secret: the server's
# host name resolves to 127.0.1.1 inside every container of the server, the
# console included (../../shared-cluster/zabbix/server.yaml). The console is
# a pod of the shared cluster, so the frontend's Service is reachable.
ZBX_API        ?= http://zabbix-web.zabbix.svc:8080/api_jsonrpc.php

CHARTS_DIR := charts
CHART_TGZ  := $(CHARTS_DIR)/$(ZABBIX_CHART)-$(ZABBIX_CHART_VERSION).tgz
PODINFO_TGZ := $(CHARTS_DIR)/$(PODINFO_CHART)-$(PODINFO_CHART_VERSION).tgz

IMAGES := zabbix/zabbix-proxy-sqlite3:alpine-$(ZABBIX_VERSION) \
          zabbix/zabbix-agent2:alpine-$(ZABBIX_VERSION) \
          registry.k8s.io/kube-state-metrics/kube-state-metrics:$(KSM_VERSION) \
          ghcr.io/stefanprodan/podinfo:$(PODINFO_CHART_VERSION)

# Trainer side: the f021bis dev cluster's kubeconfig (shared-cluster/Makefile).
CONSOLES_KUBECONFIG ?= ../../shared-cluster/kubeconfig
CONSOLES_KUBECTL := kubectl --kubeconfig=$(CONSOLES_KUBECONFIG) --context=training-f021bis -n consoles

chart: $(CHART_TGZ) $(PODINFO_TGZ)

$(CHART_TGZ):
	mkdir -p $(CHARTS_DIR)
	helm pull $(ZABBIX_CHART) --repo $(ZABBIX_CHART_REPO) --version $(ZABBIX_CHART_VERSION) -d $(CHARTS_DIR)

# Lab 3's application.
$(PODINFO_TGZ):
	mkdir -p $(CHARTS_DIR)
	helm pull $(PODINFO_CHART) --repo $(PODINFO_CHART_REPO) --version $(PODINFO_CHART_VERSION) -d $(CHARTS_DIR)

# One platform only: with the containerd image store (the default of the
# console's Docker 29), `docker pull` fetches the content of one platform of
# a multi-platform image, and `kind load docker-image` then fails with
# "ctr: content digest sha256:…: not found".
pull:
	for i in $(IMAGES) $(KIND_NODE); do docker pull -q --platform linux/amd64 $$i || exit 1; done

# For the same reason, not `kind load docker-image`: a single-platform
# archive, loaded with `kind load image-archive`.
load:
	@test -n "$(CLUSTER)" || { echo "CLUSTER is not set: source ~/.zabbix/user.env"; exit 1; }
	tmp=$$(mktemp) && for i in $(IMAGES); do \
	  docker save --platform linux/amd64 -o $$tmp $$i \
	    && kind load image-archive $$tmp --name $(CLUSTER) || { rm -f $$tmp; exit 1; }; \
	done; rm -f $$tmp

# Nothing secret on a command line: the Secret's JSON goes through a pipe.
credentials:
	install -d -m 0700 $(ZBX_DIR)
	umask 077 && s=$$(kubectl --context $(SECRET_CONTEXT) get secret zabbix-user -o json) \
	  && jq -j '.data.psk | @base64d' <<<"$$s" > $(ZBX_DIR)/user.psk \
	  && jq -r --arg psk $(ZBX_DIR)/user.psk --arg api '$(ZBX_API)' -f user-env.jq <<<"$$s" \
	       > $(ZBX_DIR)/user.env
	@echo "$(ZBX_DIR)/user.env written: source ~/.zabbix/user.env"

check:
	@ok() { printf '  %-36s %s\n' "$$1" "$$2"; }; \
	for t in kind kubectl helm docker curl git jq nc; do \
	  ok $$t "$$(command -v $$t >/dev/null 2>&1 && echo ok || echo MISSING)"; done; \
	for c in $(CHART_TGZ) $(PODINFO_TGZ); do \
	  ok "$$(basename $$c)" "$$(test -f $$c && echo ok || echo 'MISSING (make -C lab0 chart)')"; done; \
	for i in $(IMAGES) $(KIND_NODE); do \
	  ok "$$(echo $${i%@*} | sed 's|.*/||')" "$$(docker image inspect $$i >/dev/null 2>&1 && echo ok || echo 'MISSING (make -C lab0 pull)')"; done; \
	if [ ! -r $(ZBX_DIR)/user.env ]; then ok credentials 'MISSING (make -C lab0 credentials)'; exit 0; fi; \
	. $(ZBX_DIR)/user.env; ok credentials "$$ZBX_USER, cluster $$CLUSTER"; \
	ok "trapper $$ZBX_SERVER" "$$(nc -z -w 3 $${ZBX_SERVER%:*} $${ZBX_SERVER##*:} 2>/dev/null && echo open || echo UNREACHABLE)"; \
	v=$$(./zapi apiinfo.version 2>&1) && ok "API as $$ZBX_USER" "ok, server $$v" || ok "API as $$ZBX_USER" "FAILED: $$v"

pull-consoles:
	for d in $$($(CONSOLES_KUBECTL) get deploy -o name); do \
	  echo "== $$d"; \
	  $(CONSOLES_KUBECTL) exec $$d -c console -- sh -c \
	    'cd ~/trainings_exercises && git pull -q --ff-only && make -s -C f021bis/module3/lab0 chart pull' & \
	done; wait

.PHONY: chart pull load credentials check pull-consoles
