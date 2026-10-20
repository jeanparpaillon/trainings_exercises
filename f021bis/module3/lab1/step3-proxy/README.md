# Step 3 — the proxy, seen from the server

**Slides:** *One proxy per cluster* · **~10 min**

Your proxy is a pod in your cluster; the server only knows what the proxy
tells it, every second (data) and every 10 s (configuration sync,
`ZBX_PROXYCONFIGFREQUENCY`).

## Where to look

The frontend's *Administration → Proxies* is for the *Super admin* role
only: your user (role *Admin*) has no *Administration* menu at all. The
trainer shows it on screen. You ask the API:

```sh
lab0/zapi proxy.get '{"output": ["name", "state", "lastaccess", "version", "compatibility"]}' \
  | jq --arg now "$(date +%s)" 'map(.seen_s_ago = ($now|tonumber) - (.lastaccess|tonumber))'
```

You see every trainee's proxy (read), and change none (not even yours: the
trainer declared it).

| Field | Values |
| --- | --- |
| `state` | `0` unknown, `1` offline, `2` **online** |
| `lastaccess` | last contact, epoch seconds: *Last seen (age)* in the UI |
| `version` | `70031` = 7.0.31 |
| `compatibility` | `1` **current**, `2` outdated (older minor: data accepted, no configuration changes), `3` unsupported |

`lab0/zapi` is three `curl` calls (`user.login`, the call, `user.logout`):
read it.

In the UI, the proxy shows where you use it: *Monitored by* in the host
form (step 4), and the hosts' availability in *Monitoring → Hosts*.

## On purpose: the proxy goes away

```sh
kubectl -n monitoring scale deploy/zabbix-zabbix-helm-chart-proxy --replicas=0
```

Run the `proxy.get` above every 30 s for two minutes. On a dry run: still
*online* at 60 s without contact, *offline* by 90 s.

```sh
kubectl -n monitoring scale deploy/zabbix-zabbix-helm-chart-proxy --replicas=1
kubectl -n monitoring logs deploy/zabbix-zabbix-helm-chart-proxy | grep -i sqlite
```

Back *online* in ~15 s. The log says `SQLite database '/var/lib/zabbix/db_data/<name>.sqlite'
does not exist. Creating...`: the chart keeps the proxy's database on an
`emptyDir`, so a new pod starts with nothing — no configuration (fetched
again from the server), no buffered data.

Nothing was collected during those two minutes: the collector itself was
gone. What the buffer is for — the proxy running but the server
unreachable — comes in step 4, once there is data to buffer.

## Questions

- Why a proxy per cluster rather than agents talking to the server
  directly? (One outbound port; buffering; the server never needs a route
  into the cluster — neither Pod nor Service addresses are routable from
  outside.)
- The proxy's buffer settings: `kubectl -n monitoring exec
  deploy/zabbix-zabbix-helm-chart-proxy -- grep -E -A12 '^### Option:
  Proxy(Offline|Local|Buffer)' /etc/zabbix/zabbix_proxy.conf`. None is set
  (the image's entrypoint removes every parameter whose `ZBX_…` variable is
  empty), so the defaults apply: `ProxyBufferMode=disk`,
  `ProxyOfflineBuffer=1` (hour), `ProxyLocalBuffer=0`. What is kept, for how
  long, and where — and with `emptyDir`, what survives the pod being
  rescheduled? What would you set (`ZBX_PROXYOFFLINEBUFFER`,
  `zabbixProxy.persistentVolume`) in production?
