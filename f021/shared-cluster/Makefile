include fleet.env
# fleet.env is also sourced by bash: drop the quotes make would keep.
TRAINEES := $(subst ",,$(TRAINEES))

SRV = https://$(HOST)/

# Everything runs from the trainer's machine: commands that need the server
# (kind, docker) go through ssh, kubectl and flux use the kubeconfig fetched
# by `make kubeconfig`. Same layout as ../../f021bis/shared-cluster.
S       := root@$(HOST)
NAME    := training
# Where the server keeps the files of this directory it needs (kind.yaml).
REMOTE  := /root/f021

KUBECONFIG_FILE := kubeconfig
KUBECTL := kubectl --kubeconfig=$(KUBECONFIG_FILE) --context=$(NAME)
FLUX    := flux --kubeconfig=$(KUBECONFIG_FILE) --context=$(NAME)

# Flux reads the platform from this repo, at this path.
REPO_OWNER := jeanparpaillon
REPO_NAME  := trainings_exercises
REPO_PATH  := f021/shared-cluster/clusters/hstgr

export HOST CONSOLE_IMAGE

all:
	@echo "First install: make create kubeconfig image secrets bootstrap watch, then make grafana-users kubeconfigs check"
	@echo "make help for the list of targets"

# f021 replaces the f021bis cluster on the server (same ports 80/443/6443,
# kind.yaml): refuse while it is there, rather than fail halfway through
# kind create with a port already bound.
create:
	@! ssh $(S) kind get clusters 2>/dev/null | grep -qx training-f021bis || { \
	  echo 'training-f021bis still runs on the server: see "Switching from f021bis" in README.md'; exit 1; }
	ssh $(S) mkdir -p $(REMOTE)
	scp kind.yaml $(S):$(REMOTE)/kind.yaml
	ssh $(S) kind create cluster --name $(NAME) --config $(REMOTE)/kind.yaml

delete:
	ssh $(S) kind delete cluster --name $(NAME)

# Cluster-admin kubeconfig for this machine, context $(NAME), API on the
# public host name (in the certificate SANs, see kind.yaml). Git-ignored.
kubeconfig:
	ssh $(S) kind get kubeconfig --name $(NAME) \
	  | sed -e 's|https://0.0.0.0:6443|https://$(HOST):6443|' -e 's/kind-$(NAME)/$(NAME)/g' \
	  > $(KUBECONFIG_FILE)
	chmod 600 $(KUBECONFIG_FILE)
	$(KUBECTL) get nodes

# Builds the console image on the server (context streamed over ssh) and
# loads it into the kind node. After a tag change: make render, commit, push.
image:
	tar -C console -c . | ssh $(S) docker build --build-arg FLUX_VERSION=$(FLUX_VERSION) -t $(CONSOLE_IMAGE) -
	ssh $(S) kind load docker-image $(CONSOLE_IMAGE) --name $(NAME)

# tenants/ and room/consoles/ from TRAINEES. Commit and push the result:
# Flux applies it from git.
render:
	bin/render

# Every Secret the fleet expects (bin/gen-secrets: passwords, Linkerd
# identity, deploy keys…), from secrets/ (git-ignored, back it up). Before
# bootstrap, and after any change of TRAINEES.
secrets:
	bin/gen-secrets
	$(KUBECTL) apply --server-side -f secrets.yaml

# Flux, with the multi-tenancy lockdown of clusters/hstgr/flux-system. Writes
# gotk-components.yaml and gotk-sync.yaml under $(REPO_PATH) on master (a
# commit by Flux, over the empty placeholders that must already be pushed),
# and registers a read-only deploy key on the repo.
bootstrap:
	@[ -n "$$GITHUB_TOKEN" ] || { echo 'GITHUB_TOKEN=$$(gh auth token) make bootstrap'; exit 1; }
	$(FLUX) bootstrap github --owner=$(REPO_OWNER) --repository=$(REPO_NAME) \
	  --personal --branch=master --path=$(REPO_PATH) --version=v$(FLUX_VERSION) \
	  --components-extra=image-reflector-controller,image-automation-controller

watch:
	$(FLUX) get kustomizations --watch

status:
	$(FLUX) get kustomizations
	$(FLUX) get helmreleases -n flux-system

# Grafana logins = console logins (secrets/passwords.txt), once Grafana is up.
grafana-users:
	KUBECONFIG=$(KUBECONFIG_FILE) kubectl config use-context $(NAME) >/dev/null
	KUBECONFIG=$(KUBECONFIG_FILE) GRAFANA_URL=https://grafana.$(HOST) bin/grafana-users

# One kubeconfig per trainee for their own machine, in secrets/kubeconfigs/
# (bin/kubeconfigs; NAMES="user1 user2" for some).
kubeconfigs:
	bin/kubeconfigs $(NAMES)

# Module 6: each trainee's deploy key on their config repo
# $(GITHUB_OWNER)/f021-<name> (NAMES="user1 user2" for some). The repos must
# exist; then uncomment <name>-flux.yaml in tenants/kustomization.yaml.
deploy-keys:
	for n in $(or $(NAMES),$(TRAINEES)); do \
	  gh repo deploy-key add secrets/deploy-keys/$$n.pub -R $(GITHUB_OWNER)/f021-$$n -t flux || exit 1; \
	done

# Restart every console (new image, stuck terminal…). Homes are kept.
restart:
	$(KUBECTL) -n consoles rollout restart deploy

check:
	$(KUBECTL) get nodes
	$(FLUX) get kustomizations
	$(KUBECTL) -n consoles get deploy
	$(KUBECTL) get gateway -A
	@for n in $(TRAINEES); do \
	  printf '%-8s console %s\n' $$n "$$(curl -s -o /dev/null -w '%{http_code}' $(SRV)$$n/)"; \
	done
	@printf 'grafana  %s\n' "$$(curl -s -o /dev/null -w '%{http_code}' https://grafana.$(HOST)/login)"

help:
	@echo "Available targets:"
	@echo "  create        - Create the kind cluster $(NAME) on the server"
	@echo "  delete        - Delete it (and every PVC with it)"
	@echo "  kubeconfig    - Fetch a cluster-admin kubeconfig into ./$(KUBECONFIG_FILE)"
	@echo "  image         - Build the console image on the server and load it into kind"
	@echo "  render        - Generate tenants/ and room/consoles/ from TRAINEES (then commit, push)"
	@echo "  secrets       - Generate secrets.yaml from secrets/ and apply it"
	@echo "  bootstrap     - Install Flux, synced to $(REPO_OWNER)/$(REPO_NAME):$(REPO_PATH)"
	@echo "  watch, status - Flux Kustomizations / HelmReleases"
	@echo "  grafana-users - One Grafana login per trainee"
	@echo "  kubeconfigs   - One kubeconfig per trainee, client certificate (NAMES= for some)"
	@echo "  deploy-keys   - Module 6: register the trainees' deploy keys (NAMES= for some)"
	@echo "  restart       - Restart every console"
	@echo "  check         - Node, Flux, consoles (401 = up, behind basic auth), Grafana"
	@echo "  help          - Show this help message"

.PHONY: all create delete kubeconfig image render secrets bootstrap watch status grafana-users kubeconfigs deploy-keys restart check help
