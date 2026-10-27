symptom="the blog says \"Error establishing a database connection\", and nobody deployed anything"

break_it() {
  # Looks like a sensible egress lockdown: anything in the cluster except
  # the system namespace. The cluster DNS lives there: WordPress can no
  # longer resolve `mysql`.
  cat <<YAML | $K apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-in-cluster-only
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchExpressions:
              - { key: kubernetes.io/metadata.name, operator: NotIn, values: [kube-system] }
YAML
}

check_it() {
  $K exec deploy/wordpress -c wordpress -- getent hosts mysql >/dev/null 2>&1 \
    && blog_ok
}

fix_it() { $K delete networkpolicy egress-in-cluster-only --ignore-not-found >/dev/null; }
