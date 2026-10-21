symptom="the stars come and go, and the ratings pod keeps restarting"

break_it() {
  # Readiness stays right, so the new pod becomes Ready and replaces the old
  # one; liveness checks a port nothing listens on, so every ~30 s the
  # kubelet kills it, then backs off (CrashLoopBackOff).
  $K patch deploy ratings-v1 --type strategic -p '
spec:
  template:
    spec:
      containers:
        - name: ratings
          livenessProbe:
            httpGet: { path: /health, port: 9081 }' >/dev/null
  $K rollout status deploy/ratings-v1 --timeout=120s >/dev/null
}

check_it() {
  local before
  rolled_out || return 1
  before=$(restarts ratings)
  sleep 45
  [ "$(restarts ratings)" = "$before" ] && page_ok 5
}

fix_it() { :; }   # reset re-applies the probes
