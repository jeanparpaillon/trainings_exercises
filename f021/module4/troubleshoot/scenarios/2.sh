symptom="the blog does not answer at all"

break_it() {
  $K patch svc wordpress --type merge \
    -p '{"spec":{"selector":{"app":"word-press"}}}' >/dev/null
}

check_it() { blog_ok; }

fix_it() {
  $K patch svc wordpress --type merge \
    -p '{"spec":{"selector":{"app":"wordpress"}}}' >/dev/null
}
