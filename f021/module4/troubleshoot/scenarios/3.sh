symptom="a new WordPress image was released this morning, and the new version is still not live"

break_it() {
  # A tag that does not exist. The old pod keeps serving: with one replica
  # maxUnavailable rounds down to 0, so nothing looks broken from outside.
  local img
  img=$($K get deploy wordpress -o jsonpath='{.spec.template.spec.containers[?(@.name=="wordpress")].image}')
  $K set image deploy/wordpress wordpress="${img%:*}:6.80-apache" >/dev/null
}

check_it() { rolled_out && blog_ok; }

fix_it() { :; }   # reset re-applies the image
