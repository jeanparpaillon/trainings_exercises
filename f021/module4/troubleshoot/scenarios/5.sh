symptom="WordPress was given more memory an hour ago, and its pod still runs with the old setting"

break_it() {
  # Just more memory than the quota has left: the surge pod of the rolling
  # update is refused, and with one replica maxUnavailable rounds down to
  # 0, so the rollout waits forever. Nothing fails, nothing is Pending: the
  # refusal is only in the ReplicaSet's events.
  local hard used want
  hard=$(to_mi "$($K get resourcequota trainee -o jsonpath='{.status.hard.requests\.memory}')")
  used=$(to_mi "$($K get resourcequota trainee -o jsonpath='{.status.used.requests\.memory}')")
  want=$(( hard - used + 64 ))
  [ "$want" -lt 320 ] && want=320
  $K patch deploy wordpress --type strategic -p "
spec:
  template:
    spec:
      containers:
        - name: wordpress
          resources:
            requests: { memory: ${want}Mi }
            limits: { memory: ${want}Mi }" >/dev/null
}

check_it() { rolled_out && blog_ok; }

fix_it() {
  # The resources come back with `apply`; a strategy changed as the fix
  # would not (the manifests do not set one).
  $K patch deploy wordpress --type merge -p \
    '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"}}}}' >/dev/null
}
