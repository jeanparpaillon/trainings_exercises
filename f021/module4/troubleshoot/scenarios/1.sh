symptom="the black stars are gone from the page (the red ones are still there)"

break_it() {
  # reviews-v2 calls ratings on a port nothing listens on.
  # RATINGS_SERVICE_PORT is read by reviews (LibertyRestEndpoint.java) — and
  # is also the name of the variable Kubernetes injects for the `ratings`
  # Service, which an explicit env entry overrides.
  $K set env deploy/reviews-v2 -c reviews RATINGS_SERVICE_PORT=9081 >/dev/null
  $K rollout status deploy/reviews-v2 --timeout=300s >/dev/null
}

check_it() { rolled_out && page_ok 20; }

fix_it() {
  $K set env deploy/reviews-v2 -c reviews RATINGS_SERVICE_PORT- >/dev/null
}
