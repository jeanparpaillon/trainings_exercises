symptom="the blog keeps going down for a few seconds, and the wordpress pod keeps restarting"

break_it() {
  # A liveness probe on a port nothing listens on. No readiness probe, so
  # the new pod gets traffic at once and the rollout completes; then every
  # ~30 s the kubelet kills it, and backs off (CrashLoopBackOff).
  $K patch deploy wordpress --type strategic -p '
spec:
  template:
    spec:
      containers:
        - name: wordpress
          livenessProbe:
            httpGet: { path: /, port: 8080 }
            periodSeconds: 10
            failureThreshold: 3' >/dev/null
  $K rollout status deploy/wordpress --timeout=120s >/dev/null
}

check_it() {
  local before
  rolled_out || return 1
  before=$(restarts wordpress)
  sleep 45
  [ "$(restarts wordpress)" = "$before" ] && blog_ok
}

fix_it() {
  # The manifests have no probe, so `apply` would keep the one added here.
  if [ -n "$($K get deploy wordpress -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}')" ]; then
    $K patch deploy wordpress --type json \
      -p '[{"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}]' >/dev/null
  fi
}
