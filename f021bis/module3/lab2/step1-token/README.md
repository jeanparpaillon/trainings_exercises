# Step 1 — token and macros

**Slides:** *Discovering Kubernetes: templates and LLD* · **~10 min**

The Kubernetes templates do not use the agents for the cluster: the proxy
calls the API itself (script and HTTP items), with a ServiceAccount token
the chart created. Look at what that token is, and what it may do, before
giving it to the server.

## The token

```sh
kubectl -n monitoring get serviceaccount,secret
kubectl -n monitoring get secret zabbix-zabbix-helm-chart -o jsonpath='{.data.token}' | base64 -d | cut -c1-40; echo
kubectl describe clusterrole zabbix-zabbix-helm-chart
```

Read the ClusterRole: `get`/`list` on nodes, pods, services, endpoints,
namespaces, events, componentstatuses, deployments, daemonsets,
statefulsets, jobs, cronjobs; `get` on `/metrics`, `/healthz`, `/readyz`,
`/version`, and on `nodes/proxy`, `nodes/metrics`, `nodes/stats`. No write,
no Secrets.

Try it, from the console, against your cluster's API:

```sh
T=$(kubectl -n monitoring get secret zabbix-zabbix-helm-chart -o jsonpath='{.data.token}' | base64 -d)
API=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -sk -H "Authorization: Bearer $T" "$API/api/v1/nodes" | jq -r '.items[].metadata.name'
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $T" "$API/api/v1/namespaces/monitoring/secrets"
```

Two node names, then `403`. (Not from the proxy pod: its image has no
`curl`. The proxy makes the same calls itself in step 2.)

## The macros

What the two parent hosts of steps 2 and 3 get, on the host (*Macros*
tab), not on the template — you cannot edit the shipped templates:

| Macro | Value | Why |
| --- | --- | --- |
| `{$KUBE.API.URL}` | `https://kubernetes.default.svc:443` | the proxy is in the cluster: it resolves Service names. The template's default, `…svc.cluster.local:443`, works as well |
| `{$KUBE.API.TOKEN}` | the token, type **Secret text** | |
| `{$HTTP.TLS.VERIFY}` | `none` | the proxy does not trust the cluster's CA; with the default `full`, nothing is discovered (step 2) |

The other names the templates need are the chart's defaults already:
`{$KUBE.NODES.ENDPOINT.NAME}` = `zabbix-zabbix-helm-chart-agent`,
`{$KUBE.STATE.ENDPOINT.NAME}` = `zabbix-kube-state-metrics`:

```sh
kubectl -n monitoring get endpoints
```

(Read off the templates: *Data collection → Templates*, *Kubernetes nodes
by HTTP*, *Macros*.)

## Questions

- What does the token give to whoever reads the macro? `nodes/proxy` is
  the one to look at twice: it reaches every kubelet's API through the API
  server. What does Zabbix do with a *Secret text* macro (UI, API,
  export)?
- `{$HTTP.TLS.VERIFY}=none`: what could answer `kubernetes.default.svc`
  instead of your API server, and receive the token? What would you do in
  production? (The proxy image reads CA certificates from
  `/var/lib/zabbix/ssl/ssl_ca_internal/`, its `SSLCALocation`: the
  cluster's CA could be mounted there, from ConfigMap `kube-root-ca.crt`.
  Not tried.)
