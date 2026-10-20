# Module 3 — catch-up targets: put `mon-<name>`, your tenant on the server and
# ~/m3 in the state of the end of a lab, when yours is lost or hopelessly
# broken. Run from module3/, in your console, after `make -C lab0
# credentials`. An existing ~/m3 is moved aside to ~/m3.<date>, never deleted.
#
#   make catch-up-lab1   mon created if missing, images loaded; ~/m3 = lab1/solution,
#                        tagged lab1; the chart installed or upgraded from its
#                        values.yaml; your hosts on the server replaced by its hosts/
#   make catch-up-lab2   the same with lab2/solution (the parent hosts `<name> mon
#                        nodes` / `<name> mon state`), the chart's token set in their
#                        {$KUBE.API.TOKEN}; controller manager and scheduler bound
#                        to 0.0.0.0. Discovery then recreates the rest in ~1 min
#
# The pieces are targets too (mon, chart, …); the step files show the
# commands they run, this is only for getting back on track.

include versions.env

SHELL   := /bin/bash
M3      ?= $(HOME)/m3
ZBX_ENV ?= $(HOME)/.zabbix/user.env
CHART_TGZ := lab0/charts/$(ZABBIX_CHART)-$(ZABBIX_CHART_VERSION).tgz

# Every recipe line starts with this: your user.env, and kubectl / helm on
# kind-$CLUSTER whatever the current context is.
ENV = set -euo pipefail; . $(ZBX_ENV); export ZABBIX_VERSION=$(ZABBIX_VERSION); \
  k() { kubectl --context "kind-$$CLUSTER" "$$@"; }; \
  node_ip() { k get node "$$CLUSTER-$$1" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'; }

catch-up-lab1: mon
	$(MAKE) m3 LAB=lab1
	$(MAKE) chart hosts

catch-up-lab2: mon
	$(MAKE) m3 LAB=lab2
	$(MAKE) chart control-plane hosts token

mon:
	@test -r $(ZBX_ENV) || { echo "no $(ZBX_ENV): make -C lab0 credentials"; exit 1; }
	$(ENV); kind get clusters 2>/dev/null | grep -qx "$$CLUSTER" \
	  || kind create cluster --name "$$CLUSTER" --config lab1/kind.yaml --image $(KIND_NODE)
	$(ENV); kubectl config set-context "kind-$$CLUSTER" --namespace default >/dev/null
	$(MAKE) -C lab0 chart
	$(ENV); $(MAKE) -C lab0 load CLUSTER="$$CLUSTER"

# ~/m3 = $(LAB)/solution, rendered for you and your nodes; one commit, a tag.
m3:
	@test -n "$(LAB)" || { echo "LAB= not set"; exit 1; }
	test ! -e $(M3) || mv $(M3) $(M3).$$(date +%Y%m%d-%H%M%S)
	$(ENV); export CP_IP=$$(node_ip control-plane) WORKER_IP=$$(node_ip worker) CLUSTER; \
	  cd $(LAB)/solution && find . -type f | while read -r f; do \
	    case $$f in ./hosts/*) out=hosts/$$CLUSTER-$${f#./hosts/} ;; *) out=$${f#./} ;; esac; \
	    mkdir -p "$(M3)/$$(dirname "$$out")"; $(CURDIR)/lab0/render "$$f" > "$(M3)/$$out"; \
	  done
	cd $(M3) && git init -q \
	  && { git config user.email >/dev/null || git config user.email m3@localhost; } \
	  && { git config user.name >/dev/null || git config user.name m3; } \
	  && git add -A && git commit -qm "$(LAB) (catch-up)" && git tag $(LAB)

# The PSK Secret, then the chart with ~/m3/values.yaml.
chart:
	$(ENV); k create namespace monitoring --dry-run=client -o yaml | k apply -f - >/dev/null; \
	  k -n monitoring create secret generic zabbix-proxy-psk --from-file=psk="$$ZBX_PSK_FILE" \
	    --dry-run=client -o yaml | k apply -f - >/dev/null; \
	  helm --kube-context "kind-$$CLUSTER" upgrade --install zabbix $(CHART_TGZ) \
	    -n monitoring -f $(M3)/values.yaml; \
	  k -n monitoring rollout restart deploy/zabbix-zabbix-helm-chart-proxy >/dev/null; \
	  k -n monitoring rollout status deploy/zabbix-zabbix-helm-chart-proxy --timeout=180s

# Your hosts on the server: every host of host group <name> deleted (with
# what their discovery rules created), then ~/m3/hosts/ imported (lab0/import:
# why not a plain configuration.import).
hosts:
	$(ENV); \
	  gid=$$(lab0/zapi hostgroup.get "$$(jq -nc --arg n "$$ZBX_USER" '{output: ["groupid"], filter: {name: [$$n]}}')" | jq -r '.[0].groupid'); \
	  ids=$$(lab0/zapi host.get "$$(jq -nc --arg g "$$gid" '{output: ["hostid"], groupids: [$$g]}')" | jq -c 'map(.hostid)'); \
	  [ "$$ids" = '[]' ] || { lab0/zapi host.delete "$$ids" >/dev/null && echo "hosts deleted: $$ids"; }; \
	  lab0/import $(M3)/hosts/*.yaml

# Lab 2 step 5: the metrics ports of the controller manager and the scheduler
# on the node's address; the kubelet restarts both static pods.
control-plane:
	$(ENV); for c in kube-controller-manager kube-scheduler; do \
	  docker exec "$$CLUSTER-control-plane" sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' \
	    /etc/kubernetes/manifests/$$c.yaml; done

# {$KUBE.API.TOKEN} of your hosts that have one: an export leaves secret
# macros without their value. The token goes through stdin, never argv.
token:
	$(ENV); tok=$$(k -n monitoring get secret zabbix-zabbix-helm-chart -o jsonpath='{.data.token}' | base64 -d); \
	  gid=$$(lab0/zapi hostgroup.get "$$(jq -nc --arg n "$$ZBX_USER" '{output: ["groupid"], filter: {name: [$$n]}}')" | jq -r '.[0].groupid'); \
	  lab0/zapi usermacro.get "$$(jq -nc --arg g "$$gid" '{output: ["hostmacroid"], groupids: [$$g], filter: {macro: "{$$KUBE.API.TOKEN}"}}')" \
	    | jq -r '.[].hostmacroid' | while read -r id; do \
	      TOK=$$tok jq -nc --arg i "$$id" '{hostmacroid: $$i, value: env.TOK, type: 1}' \
	        | lab0/zapi usermacro.update - >/dev/null && echo "token set: macro $$id"; done

.PHONY: catch-up-lab1 catch-up-lab2 mon m3 chart hosts control-plane token
