# Step 2 — metrics: the database, and the edge

**Slide:** Lab — monitoring: metrics · **~15 min**

Two sources of application metrics, neither of them in WordPress's code:

- **an exporter** next to MySQL: `mysqld-exporter`, a sidecar in the MySQL
  pod, translating `SHOW GLOBAL STATUS` into Prometheus metrics on port
  9104 — plus a **PodMonitor** that tells Prometheus to scrape it;
- **the edge**: Traefik counts every request it routes to your Service —
  status code and duration. The platform scrapes Traefik; you only query.

```sh
kubectl -n "$NS" apply -k monitoring/step2-metrics
kubectl -n "$NS" rollout status sts/mysql            # the pod is replaced: one more container
kubectl -n "$NS" get pod mysql-0                     # 2/2
kubectl -n "$NS" exec mysql-0 -c exporter -- wget -qO- localhost:9104/metrics | grep '^mysql_up'
```

Read [`kustomization.yaml`](kustomization.yaml) and
[`podmonitor.yaml`](podmonitor.yaml): which label and which port name tie
them together?

## Explore

Wait one scrape (30 s), then:

```text
# the target exists and answers
up{namespace="<ns>"}

# MySQL, through its exporter
mysql_up{namespace="<ns>"}
mysql_global_status_threads_connected{namespace="<ns>"}
rate(mysql_global_status_queries{namespace="<ns>"}[1m])

# the blog, as Traefik sees it: Rate, Errors, Duration
sum by (code) (rate(traefik_service_requests_total{service="<ns>-wordpress-80@kubernetes"}[1m]))
histogram_quantile(0.95, sum by (le) (
  rate(traefik_service_request_duration_seconds_bucket{service="<ns>-wordpress-80@kubernetes"}[5m])))
```

Your HTTPRoute of module 2 has its own series: look for
`service=~"httproute-<ns>-.*"`.

## Questions to answer before moving on

- `up` is 1, `mysql_up` is 0: what is broken, and what is not?
- The exporter logs in as `wordpress`, with the application's password.
  What would you change in production?
- Traefik measures the blog without a line of code in WordPress. What can
  it **not** tell you that only the application could?
