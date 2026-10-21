symptom="reviews-v2 was given more memory an hour ago, and its pods still run with the old setting"

break_it() {
  # Just more memory than the quota has left: the surge pod of the rolling
  # update is refused, and with 2 replicas maxUnavailable rounds down to 0,
  # so the rollout waits forever. Nothing fails, nothing is Pending: the
  # refusal is only in the ReplicaSet's events.
  local hard used want
  hard=$(to_mi "$($K get resourcequota trainee -o jsonpath='{.status.hard.requests\.memory}')")
  used=$(to_mi "$($K get resourcequota trainee -o jsonpath='{.status.used.requests\.memory}')")
  want=$(( hard - used + 64 ))
  [ "$want" -lt 320 ] && want=320
  $K patch deploy reviews-v2 --type strategic -p "
spec:
  template:
    spec:
      containers:
        - name: reviews
          resources:
            requests: { memory: ${want}Mi }
            limits: { memory: ${want}Mi }" >/dev/null
}

check_it() { rolled_out && page_ok 5; }

fix_it() { :; }   # reset re-applies the resources
