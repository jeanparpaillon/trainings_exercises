# Shared by break, check, reset and the scenarios. Not for you to run.
# Needs only what the web console has: bash, kubectl, curl, sed.
set -euo pipefail
NS=${NS:?export NS=<your-namespace> first}
# Host suffix of the Ingresses: the shared cluster's by default; on a local
# kind cluster, export NIP=127.0.0.1.nip.io.
NIP=${NIP:-195.35.2.222.nip.io}
K="kubectl -n $NS"
PAGE=http://bookinfo.$NS.$NIP/productpage
BLOG=http://wordpress.$NS.$NIP/
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
module3=$here/../../module3
storage=$here/../../module2/storage

die() { echo "$*" >&2; exit 1; }

# N page loads; fails if any is not a 200 with every box shown, or takes
# longer than MAX seconds. productpage answers 200 with an apology when a
# dependency fails: the status code alone says nothing.
page_ok() {
  local n=${1:-20} max=${2:-3} i out code t
  for i in $(seq "$n"); do
    out=$(curl -s -m 10 -w '\n%{http_code} %{time_total}' "$PAGE") || return 1
    read -r code t <<<"$(tail -n1 <<<"$out")"
    [ "$code" = 200 ] || return 1
    awk -v t="$t" -v m="$max" 'BEGIN { exit !(t <= m) }' || return 1
    grep -q 'currently unavailable\|Error fetching' <<<"$out" && return 1
  done
  return 0
}

# WordPress answers with its own content: not a database error, and not a
# redirect to the installer (an empty database).
blog_ok() {
  local out
  out=$(curl -s -m 10 -w '\n%{http_code} %{redirect_url}' "$BLOG") || return 1
  grep -q 'Error establishing a database connection' <<<"$out" && return 1
  grep -q 'install\.php' <<<"$(tail -n1 <<<"$out")" && return 1
  grep -q '^200 \|^30[12] ' <<<"$(tail -n1 <<<"$out")"
}

# Every Deployment rolled out.
rolled_out() {
  local d
  for d in $($K get deploy -o name); do
    $K rollout status "$d" --timeout="${1:-5s}" >/dev/null 2>&1 || return 1
  done
}

# Sum of a deployment's container restarts.
restarts() {
  $K get pods -l app="$1" \
    -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' \
    | awk '{ s += $1 } END { print s + 0 }'
}

# A quantity (1968Mi, 2Gi, 2063597568, 512M…) in MiB, rounded up.
to_mi() {
  awk -v q="$1" 'BEGIN {
    n = q + 0; u = q; sub(/^[0-9.]+/, "", u)
    f["Ki"] = 1024; f["Mi"] = 1048576; f["Gi"] = 1073741824
    f["k"] = 1e3; f["M"] = 1e6; f["G"] = 1e9; f[""] = 1
    b = n * f[u]; m = b / 1048576
    printf "%d\n", (m == int(m)) ? m : int(m) + 1
  }'
}
