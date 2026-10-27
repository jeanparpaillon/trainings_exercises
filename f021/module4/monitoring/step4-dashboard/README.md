# Step 4 — dashboard as code

**Slide:** Lab — monitoring: dashboard · **~10 min**

A dashboard clicked together in the UI is lost at the next reinstall and
reviewed by nobody. This one is a ConfigMap, labelled
`grafana_dashboard: "1"`: Grafana's sidecar loads it from any namespace.

```sh
sed "s/CHANGEME/$NS/g" monitoring/step4-dashboard/dashboard.yaml.tmpl \
  > monitoring/step4-dashboard/dashboard.yaml
kubectl -n "$NS" apply -k monitoring/step4-dashboard
```

Grafana → *Dashboards* → search **WordPress — <your-ns>**: requests per
status code and p95 from Traefik, MySQL connections and queries, memory
against limits, restarts.

## Change it

1. In Grafana, edit a panel and try to save: refused, the dashboard is
   provisioned.
2. Instead: change a title or a query in `dashboard.yaml`, apply, reload
   the page — the change is there.
3. To start from the UI: build the panel there, *Export* → *JSON*, paste
   it into the ConfigMap.

## Questions to answer before moving on

- The uid and the title carry your namespace: what would happen in a
  shared Grafana without it?
- Where should this ConfigMap live in a real project — with the platform,
  or next to the application's manifests?

## Keep it

The troubleshooting lab starts here (`troubleshoot/reset` applies this
step): watch your dashboard and your alerts while you look for the
faults.
