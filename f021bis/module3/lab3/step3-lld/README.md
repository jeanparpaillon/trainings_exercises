# Step 3 — discovery from Prometheus metrics

**Slides:** *Collecting Prometheus metrics in Zabbix* · **~15 min**

Step 2 named every series by hand. The labels can do it: a discovery
rule, dependent on the same master item, turns the series of one metric
into LLD rows, one per label combination, and item prototypes follow.
Two rules: requests per path and status, then the latency histogram's
buckets — which give the p95 the mean was hiding.

## Requests per path and status

*Discovery rules → Create discovery rule* on `<name> podinfo`:

| Field | Value |
| --- | --- |
| Name | `podinfo: requests discovery` |
| Type | *Dependent item*, master `podinfo: metrics` |
| Key | `podinfo.requests.discovery` |
| Preprocessing | *Prometheus to JSON*, `http_request_duration_seconds_count` |
| LLD macros | `{#PATH}` = `$.labels.path`, `{#STATUS}` = `$.labels.status` |

*Test* it: the JSON has one row per series, with its `labels`. That is what
the LLD macros read.

*Item prototypes → Create item prototype*:

| Field | Value |
| --- | --- |
| Name | `podinfo: /{#PATH} {#STATUS} per second` |
| Type | *Dependent item*, master `podinfo: metrics` |
| Key | `podinfo.requests.rate[{#PATH},{#STATUS}]` |
| Type of information, units | *Numeric (float)*, `rps` |
| Preprocessing | *Prometheus pattern* `http_request_duration_seconds_count{path="{#PATH}",status="{#STATUS}"}`, *function* `sum`; *Change per second* |

`http_request_duration_seconds_count`, not `http_requests_total`: only
the histogram has `path`.

Within a minute, *Latest data*: one item per row. On the dry run six:
`root 200` (~2.4/s), `status 500` and `delay 200` (~0.33/s each),
`healthz 200` and `readyz 200` (0.1/s: the kubelet's probes), and
`metrics 200` (0.033/s: one read every 30 s — Zabbix itself).

### A new path

Hit a route the load never uses, and watch an item appear at the next
read:

```sh
kubectl -n podinfo exec deploy/load -- curl -s podinfo:9898/version
kubectl -n podinfo exec deploy/load -- curl -s -o /dev/null podinfo:9898/status/404
```

`/status/404` does not create a new *path*: it is `status`, with a new
*status*.

## The latency buckets, and the p95

A histogram is a set of counters, one per upper bound `le`: requests that
took at most 0.005 s, 0.01 s… 10 s, `+Inf`. The bounds are the same in
every series; read them from one series, the one sure to exist — Zabbix's
own read:

| Field | Value |
| --- | --- |
| Name | `podinfo: latency buckets discovery` |
| Key | `podinfo.buckets.discovery` (dependent, same master) |
| Preprocessing | *Prometheus to JSON*, `http_request_duration_seconds_bucket{path="metrics"}` |
| LLD macros | `{#LE}` = `$.labels.le` |

Item prototype: `podinfo: requests under {#LE} s`, key
`podinfo.bucket[{#LE}]`, float, *Prometheus pattern*
`http_request_duration_seconds_bucket{le="{#LE}"}`, *function* `sum` (all
paths and statuses together) — **no** *Change per second*: the function
below wants the raw counters.

Then an ordinary *Calculated* item on the host:

| Name | Key | Units | Formula |
| --- | --- | --- | --- |
| `podinfo: p95 latency` | `podinfo.latency.p95` | `s` | `bucket_percentile(//podinfo.bucket[*],5m,95)` |

`bucket_percentile` takes the increase of each bucket over 5 minutes,
reads the bound from the key's parameter, and interpolates inside the
bucket that holds the 95 % mark — what PromQL's `histogram_quantile` does.

On the dry run: **p95 1.70 s, mean 0.09 s**, same traffic. 90 % of the
requests take ~1 ms, the tenth takes 1 s: the p95 lands in the bucket
(1 s, 2.5 s], halfway.

Discovering on every series instead of one gives the rule an error: each
`le` comes once per path and status, so the same key is generated again
and again (`Cannot create item: item with the same key
"podinfo.bucket[2.5]" already exists`). The items are created; the rule
stays red.

## Questions

- Which label must **never** be a discovery key? `path` here is the route,
  six values. What if it were the URL (`/users/1234`), the pod's name, a
  request ID? What does each new value cost in Zabbix (an item, its
  history, its trends) and in Prometheus (a series)?
- The first rule's items are kept 7 days after they disappear (the rule's
  default): a path no longer used is still there next week. Is that what
  you want?
- p95 1.7 s, mean 0.09 s: which one would you alert on, and which one
  would the application's users agree with?
