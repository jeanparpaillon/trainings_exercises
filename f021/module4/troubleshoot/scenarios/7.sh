symptom="the blog says \"Error establishing a database connection\" since MySQL was moved to faster storage"

break_it() {
  # The StatefulSet is recreated with a claim template on a StorageClass
  # that does not exist (claim templates are immutable: delete and
  # recreate is how it is done). The new claim stays Pending, so does
  # mysql-0. Second trap, for the fix: the template is also renamed, so
  # fixing the class alone gives MySQL a new, empty volume — WordPress then
  # asks to be installed again, and data-mysql-0 sits unused.
  $K delete sts mysql --wait=true >/dev/null
  sed -e 's/storageClassName: standard/storageClassName: fast/' \
      -e 's/name: data$/name: fast/' \
      "$storage/step3-statefulset/mysql-statefulset.yaml" | $K apply -f - >/dev/null
}

check_it() {
  local claims
  $K rollout status sts/mysql --timeout=5s >/dev/null 2>&1 || return 1
  claims=$($K get pod mysql-0 -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}')
  grep -qw data-mysql-0 <<<"$claims" && blog_ok
}

fix_it() {
  if [ "$($K get sts mysql -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null)" != data ]; then
    $K delete sts mysql --ignore-not-found --wait=true >/dev/null
    $K apply -f "$storage/step3-statefulset/mysql-statefulset.yaml" >/dev/null
  fi
  $K delete pvc fast-mysql-0 --ignore-not-found --wait=false >/dev/null
}
