# Image of the trainees' web consoles (templates/console.yaml.tmpl).
# Built on the server and loaded into the kind node (make image): no
# registry involved. Bump CONSOLE_IMAGE in fleet.env on every change, then
# make render, commit, push: kind-loaded images are never re-pulled, a new
# tag is what rolls the consoles.
#
# Derived from the f021bis console (../../f021bis/shared-cluster/console),
# without its Docker / kind / etcd / ansible: f021 trainees work on the shared
# cluster only. FLUX_VERSION must match the controllers (fleet.env).
FROM ubuntu:24.04

ARG TTYD_VERSION=1.7.7
ARG KUBERNETES_MINOR=v1.37
ARG HELM_VERSION=v4.3.0
ARG FLUX_VERSION=2.9.6

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg tini \
      bash-completion less vim nano jq git make openssh-client \
      iproute2 iputils-ping dnsutils netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*

# kubectl from its apt repository: it follows the cluster's minor version.
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends kubectl \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; cd /tmp \
 && curl -fsSLO "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
 && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/SHA256SUMS" \
      | grep ' ttyd.x86_64$' | sha256sum -c - \
 && install -m 0755 ttyd.x86_64 /usr/local/bin/ttyd \
 && f="helm-${HELM_VERSION}-linux-amd64.tar.gz" \
 && curl -fsSLO "https://get.helm.sh/$f" \
 && curl -fsSLO "https://get.helm.sh/$f.sha256sum" \
 && sha256sum -c "$f.sha256sum" \
 && tar -xzf "$f" linux-amd64/helm \
 && install -m 0755 linux-amd64/helm /usr/local/bin/helm \
 && f="flux_${FLUX_VERSION}_linux_amd64.tar.gz" \
 && curl -fsSLO "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/$f" \
 && curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_checksums.txt" \
      | grep " $f\$" | sha256sum -c - \
 && tar -xzf "$f" flux \
 && install -m 0755 flux /usr/local/bin/flux \
 && rm -rf /tmp/*

COPY console-init /usr/local/bin/console-init

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/console-init"]
