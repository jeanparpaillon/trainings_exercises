symptom="the blog says \"Error establishing a database connection\" since WordPress was restarted this morning"

break_it() {
  # Someone "rotated" the database password: a new value in the Secret,
  # then a restart so that WordPress picks it up. MySQL does not: it reads
  # MYSQL_PASSWORD only when it initialises an empty data directory, and
  # its data is on a persistent volume since module 2. WordPress now sends
  # a password MySQL never heard of.
  local new
  secret_pw > "$state/1.password"
  new=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 16)
  $K patch secret wordpress-db -p "{\"stringData\":{\"password\":\"$new\"}}" >/dev/null
  $K rollout restart deploy/wordpress >/dev/null
  $K rollout status deploy/wordpress --timeout=300s >/dev/null
}

check_it() { rolled_out && blog_ok; }

fix_it() {
  # Back to the password MySQL was initialised with — on both sides, in
  # case the fix was to change MySQL's password instead of the Secret's.
  local old cur pw
  if [ -s "$state/1.password" ]; then
    old=$(cat "$state/1.password")
  else
    old=$(sed -n 's/^password=//p' "$module1/wordpress/step2-config/db.env" 2>/dev/null || true)
  fi
  [ -n "$old" ] || return 0
  cur=$(secret_pw)
  for pw in "$old" "$cur"; do
    if mysql_pw_ok "$pw"; then
      [ "$pw" = "$old" ] || $K exec mysql-0 -c mysql -- env MYSQL_PWD="$pw" \
        mysql -uwordpress -e "ALTER USER CURRENT_USER() IDENTIFIED BY '$old'" >/dev/null
      break
    fi
  done
  if [ "$cur" != "$old" ]; then
    $K patch secret wordpress-db -p "{\"stringData\":{\"password\":\"$old\"}}" >/dev/null
    $K rollout restart deploy/wordpress >/dev/null
  fi
  rm -f "$state/1.password"
}
