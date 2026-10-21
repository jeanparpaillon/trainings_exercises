symptom="reviews-v3 was released this morning with a new image tag, and the new version is still not live"

break_it() {
  # A tag that does not exist. The old pod keeps serving: maxUnavailable
  # rounds down to 0 with one replica, so nothing looks broken from outside.
  local img
  img=$($K get deploy reviews-v3 -o jsonpath='{.spec.template.spec.containers[?(@.name=="reviews")].image}')
  $K set image deploy/reviews-v3 reviews="${img%:*}:1.20.30" >/dev/null
}

check_it() { rolled_out && page_ok 5; }

fix_it() { :; }   # reset re-applies the image
