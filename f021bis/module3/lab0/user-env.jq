# Secret zabbix-user (kubectl -o json) -> ~/.zabbix/user.env. Called by
# `make credentials` with --arg psk <PSK file> --arg api <API URL>.
.data | map_values(@base64d) | [
  "# make -C lab0 credentials, from Secret zabbix-user (shared cluster). Do not commit.",
  "ZBX_USER=\(.name | @sh)",
  "ZBX_PASSWORD=\(.password | @sh)",
  "ZBX_PSK_IDENTITY=\(.psk_identity | @sh)",
  "ZBX_PSK_FILE=\($psk | @sh)",
  "ZBX_SERVER=\(.server | @sh)",
  "ZBX_URL=\(.url | @sh)",
  "ZBX_API=\($api | @sh)",
  "CLUSTER=mon-\(.name)",
  "export ZBX_USER ZBX_PASSWORD ZBX_PSK_IDENTITY ZBX_PSK_FILE ZBX_SERVER ZBX_URL ZBX_API CLUSTER"
] | .[]
