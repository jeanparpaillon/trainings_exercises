# Step 2 — proxy and agents with the Helm chart

**Slides:** *The Zabbix Helm chart* · **~20 min**

The official chart deploys what a cluster needs to be monitored by an
existing server: a proxy (Deployment), an agent 2 per node (DaemonSet,
`hostNetwork`), kube-state-metrics, and a read-only ServiceAccount for the
API (lab 2). It deploys no server: yours is the room's.

## The values

```sh
cp lab1/step2-chart/values.yaml ~/m3/values.yaml
```

Complete every `TODO` in `~/m3/values.yaml`, from `~/.zabbix/user.env` and
`versions.env`:

| Value | From |
| --- | --- |
| both image tags | `alpine-$ZABBIX_VERSION`: same major as the server for the proxy to be accepted, same tag for one version in the room |
| `ZBX_HOSTNAME` | `$ZBX_USER`: the proxy's name as **declared on the server**; the server knows no other |
| `ZBX_SERVER_HOST` | `$ZBX_SERVER`: IP and port, `<ip>:<port>` |
| `ZBX_TLSCONNECT` | `psk`: the server accepts nothing else from your proxy |
| `ZBX_TLSPSKIDENTITY` | `$ZBX_PSK_IDENTITY` |
| `ZBX_TLSPSKFILE` | `psk`: the key of the Secret below, mounted in `/var/lib/zabbix/enc/` |

Read the rest of the file before installing: why `env` repeats values the
chart already had, and why the PSK is a mounted file and not a variable.

## The PSK, then the chart

```sh
kubectl config current-context          # kind-mon-<name>
kubectl create namespace monitoring
kubectl -n monitoring create secret generic zabbix-proxy-psk --from-file=psk="$ZBX_PSK_FILE"
helm install zabbix lab0/charts/$ZABBIX_CHART-$ZABBIX_CHART_VERSION.tgz \
  -n monitoring -f ~/m3/values.yaml
```

The release is named `zabbix`: its objects are
`zabbix-zabbix-helm-chart-proxy`, `-agent`…, the names lab 2's templates
expect by default.

## Check

```sh
kubectl -n monitoring get pods -o wide
kubectl -n monitoring logs deploy/zabbix-zabbix-helm-chart-proxy | grep -v Updating
```

| What | Expected |
| --- | --- |
| proxy | 1 pod, a pod IP (`10.244.…`) |
| agents | one per node, **the node's IP** (`hostNetwork`) |
| kube-state-metrics | 1 pod, `Running` (used from lab 2 on) |
| proxy log | `Starting Zabbix Proxy (active) [<name>]. Zabbix 7.0.31`, then no `cannot …` line |

The proxy starts in seconds; its first configuration sync follows
immediately. Step 3 looks at it from the server.

## When it does not connect

Everything is in the proxy's log. Seen on a local dry run, except the
rows marked *expected* (to confirm on the server):

| Log line | Cause |
| --- | --- |
| `cannot send proxy data to server at "…": connection of type "unencrypted" is not allowed for proxy "<name>"` | `ZBX_TLSCONNECT` = `unencrypted` |
| `Unable to connect to […]: TCP successful, cannot establish TLS … handshake failure` | wrong PSK identity or PSK (the server logs `cannot find requested PSK identity "…"`: ask the trainer) |
| `cannot connect to [[127.0.1.1]:10051]…` | the server's **host name** in `ZBX_SERVER_HOST` instead of its IP — *expected* |
| `Unable to connect …: connection timed out` | wrong IP or port; or the link is cut (step 4) |
| pod `ContainerCreating`, event `secret "zabbix-proxy-psk" not found` | the Secret was not created first; create it, the pod starts by itself — *expected* |

A proxy of another major version is refused by the server as
incompatible (not tried on the dry run).

Fix `~/m3/values.yaml`, then:

```sh
helm upgrade zabbix lab0/charts/$ZABBIX_CHART-$ZABBIX_CHART_VERSION.tgz -n monitoring -f ~/m3/values.yaml
```

## Questions

- The agent's `ZBX_SERVER_HOST` is `0.0.0.0/0` in the chart's defaults
  (`helm show values lab0/charts/…`): who may query an agent on
  `<node IP>:10050`? What would you set on a production cluster?
- Why `hostNetwork` for the agent? What would it monitor without it?
- `--from-file=psk="$ZBX_PSK_FILE"`: where is the PSK now, and who can read
  it (`kubectl auth can-i get secret -n monitoring --as …`)?
