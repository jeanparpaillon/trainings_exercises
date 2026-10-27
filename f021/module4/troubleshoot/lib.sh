# Shared by break, check, reset and the scenarios. Not for you to run.
# Needs only what the web console has: bash, kubectl, curl, sed, base64.
set -euo pipefail
NS=${NS:?export NS=<your-namespace> first}
# Host suffix of the Ingresses: the shared cluster's by default; on a local
# kind cluster, export NIP=127.0.0.1.nip.io.
NIP=${NIP:-195.35.2.222.nip.io}
K="kubectl -n $NS"
BLOG=http://wordpress.$NS.$NIP/
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
module1=$here/../../module1
module2=$here/../../module2
storage=$module2/storage
# What a scenario must remember to undo itself (git-ignored).
state=$here/.state
mkdir -p "$state"

die() { echo "$*" >&2; exit 1; }

# N loads of the blog's home page through the Ingress; fails on anything
# but WordPress's own content: an error page ("Error establishing a
# database connection" is a 500), a redirect to the installer (an empty
# database), a Traefik 404 / 502 / 503, or more than MAX seconds.
blog_ok() {
  local n=${1:-5} max=${2:-5} i out code t
  for i in $(seq "$n"); do
    out=$(curl -s -m 10 -w '\n%{http_code} %{time_total} %{redirect_url}' "$BLOG") || return 1
    read -r code t _ <<<"$(tail -n1 <<<"$out")"
    [ "$code" = 200 ] || return 1
    awk -v t="$t" -v m="$max" 'BEGIN { exit !(t <= m) }' || return 1
    grep -q 'Error establishing a database connection\|install\.php' <<<"$out" && return 1
  done
  return 0
}

# Every Deployment and StatefulSet rolled out.
rolled_out() {
  local d
  for d in $($K get deploy,sts -o name); do
    $K rollout status "$d" --timeout="${1:-5s}" >/dev/null 2>&1 || return 1
  done
}

# Sum of a workload's container restarts, by app label.
restarts() {
  $K get pods -l app="$1" \
    -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' \
    | awk '{ s += $1 } END { print s + 0 }'
}

# Does this password open MySQL for the `wordpress` user?
mysql_pw_ok() {
  $K exec mysql-0 -c mysql -- env MYSQL_PWD="$1" \
    mysql -uwordpress -e 'SELECT 1' >/dev/null 2>&1
}

# The password currently in the Secret.
secret_pw() {
  $K get secret wordpress-db -o jsonpath='{.data.password}' | base64 -d
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
