# Step 2 — nodes by discovery

**Slides:** *Discovering Kubernetes: templates and LLD* · **~15 min**

## First, lab 1's hosts go

Discovery creates hosts named after the nodes, `mon-<name>-control-plane`
and `mon-<name>-worker`: the names of lab 1's hosts. Host names are unique,
and discovery fails while those exist — disabling them is not enough.
They are exported in `~/m3/hosts/` (lab 1 step 5):

*Data collection → Hosts*, select both, *Delete*. Or:

```sh
ids=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$CLUSTER-control-plane\", \"$CLUSTER-worker\"]}}" | jq -c 'map(.hostid)')
lab0/zapi host.delete "$ids"
```

## The parent host

*Data collection → Hosts → Create host*:

| Field | Value |
| --- | --- |
| Host name | `<name> mon nodes` (`$ZBX_USER mon nodes`) |
| Templates | *Kubernetes nodes by HTTP* (*Templates/Applications*) |
| Host groups | `<name>` |
| Interfaces | none: everything goes through the API |
| Monitored by | *Proxy*, `<name>` |
| Macros | the three of step 1 |

Its master item, *Get nodes*, runs every minute at second 00 (interval
`0;s00`): no discovery interval to lower. On a dry run the two node hosts
appeared 26 s after the macros were right.

## What to look for

- *Monitoring → Hosts*, search `mon-<name>`: two hosts, **discovered**
  (you cannot edit them: they are in host group `Applications`, which you
  only read), linked to *Linux by Zabbix agent*, agent interface = the
  node's current IP (from the agents' Endpoints), monitored by your proxy.
- The other trainees' nodes, as they get there.
- On `<name> mon nodes` itself (*Latest data*): node allocatable,
  capacity, conditions, and 8 items per pod, of every namespace (178 items
  on the dry run).

Without the UI:

```sh
lab0/zapi host.get "{\"output\": [\"host\", \"flags\"], \"search\": {\"host\": \"$CLUSTER-\"},
  \"selectGroups\": [\"name\"], \"selectInterfaces\": [\"ip\"]}" | jq -c '.[]'
```

`flags: 4` = discovered. The truth is `kubectl get nodes -o wide`: the
hosts follow it, within a minute.

## When nothing is discovered

*Latest data* of `<name> mon nodes`, item *Get nodes check*:

| Value | Cause |
| --- | --- |
| `SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)` | `{$HTTP.TLS.VERIFY}` still `full` (seen on the dry run) |
| `Resolving timed out` (proxy log) | the cluster's DNS or kube-proxy: `kubectl -n kube-system get pods` |
| HTTP 401 | the token macro: empty, or not the whole token |
| no value at all | the host is not *monitored by* your proxy |

The proxy's log has the script's errors: `kubectl -n monitoring logs
deploy/zabbix-zabbix-helm-chart-proxy | grep Kubernetes`.

## Questions

- Lab 1's hosts and these collect the same items. What was lost by
  deleting them (their history), which would you keep in production, and
  what happens to each when a node is replaced?
- The discovered hosts are in `Applications`, read-only to you: where do
  you change something for them (the parent's macros; step 3)?
