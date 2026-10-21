symptom="the page does not answer at all"

break_it() {
  $K patch svc productpage --type merge \
    -p '{"spec":{"selector":{"app":"product-page"}}}' >/dev/null
}

check_it() { page_ok 5; }

fix_it() {
  $K patch svc productpage --type merge \
    -p '{"spec":{"selector":{"app":"productpage"}}}' >/dev/null
}
