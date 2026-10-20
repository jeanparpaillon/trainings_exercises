# Step 2 — one master item, dependent items

**Slides:** *Collecting Prometheus metrics in Zabbix* · **~20 min**

One HTTP request to `/metrics` every 30 s, on the proxy; every number is
extracted from that one answer by preprocessing. On a host first, where
you can test each item; step 4 moves it all into a template.

## The host

*Data collection → Hosts → Create host*:

| Field | Value |
| --- | --- |
| Host name | `<name> podinfo` (`$ZBX_USER podinfo`) |
| Host groups | `<name>` |
| Interfaces | none: the HTTP agent needs none |
| Monitored by | *Proxy*, `<name>`: it is in the cluster, it resolves `podinfo.podinfo.svc` |

## The master item

*Items → Create item*:

| Field | Value |
| --- | --- |
| Name | `podinfo: metrics` |
| Type | *HTTP agent* |
| Key | `podinfo.metrics` |
| URL | `http://podinfo.podinfo.svc:9898/metrics` |
| Type of information | *Text* |
| Update interval | `30s` |
| History | *Do not store*: the raw text is ~20 KB a read, and worth nothing once the numbers are out of it |

## The dependent items

Each: *Type* *Dependent item*, *Master item* `podinfo: metrics`, *Type of
information* *Numeric (float)*, and in *Preprocessing* a step *Prometheus
pattern* (pattern, then *value* or *function*), plus *Change per second*
for every counter. Create the first, then *Clone* it.

| Name | Key | Units | Prometheus pattern | Then |
| --- | --- | --- | --- | --- |
| `podinfo: started` | `podinfo.started` | `unixtime` | `process_start_time_seconds`, *value* | |
| `podinfo: requests per second` | `podinfo.requests.rate` | `rps` | `http_requests_total`, *function* `sum` | *Change per second* |
| `podinfo: 5xx per second` | `podinfo.errors.rate` | `rps` | `http_requests_total{status=~"5.."}`, *function* `sum` | *Change per second* |
| `podinfo: time spent per second` | `podinfo.duration.sum.rate` | `s` | `http_request_duration_seconds_sum`, *function* `sum` | *Change per second* |
| `podinfo: requests timed per second` | `podinfo.duration.count.rate` | `rps` | `http_request_duration_seconds_count`, *function* `sum` | *Change per second* |

*Test* (bottom of the item form) with *Get value from host* runs the
master's request and your preprocessing on it, now: faster than waiting
30 s, and it shows each step's result.

`sum`: the histogram has one series per `method`/`path`/`status`, and
`{status=~"5.."}` may match several. *value* refuses a pattern that
matches more than one series.

## The mean latency

A *Calculated* item, no preprocessing:

| Name | Key | Units | Formula |
| --- | --- | --- | --- |
| `podinfo: mean latency` | `podinfo.latency.mean` | `s` | `last(//podinfo.duration.sum.rate)/last(//podinfo.duration.count.rate)` |

Seconds spent per second, divided by requests per second: the mean over
the last 30 s. (`_count` of the same histogram rather than
`http_requests_total`: the same number here, but only the histogram's own
count is guaranteed to pair with its `_sum`.)

If time: the share of requests under 0.5 s, the SLO-shaped number of the
slides — `podinfo.duration.le05.rate` from
`http_request_duration_seconds_bucket{le="0.5"}` (*sum*, *Change per
second*), and a calculated `podinfo.latency.under05`, `%`,
`100*last(//podinfo.duration.le05.rate)/last(//podinfo.duration.count.rate)`.

## What to look for

*Monitoring → Latest data*, host `<name> podinfo`, within a minute or two
(the first value of a *Change per second* item needs two reads). On the
dry run:

| Item | Value | Why |
| --- | --- | --- |
| requests per second | 3.1–3.3 | the load's ~3.1, plus the probes and Zabbix's own read |
| 5xx per second | ~0.3 | one in ten |
| mean latency | ~0.1 s | one in ten takes 1 s, the rest ~1 ms |
| under 0.5 s | ~90 % | the same one in ten |

Without the UI:

```sh
H=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$ZBX_USER podinfo\"]}}" | jq -r '.[0].hostid')
lab0/zapi item.get "{\"output\": [\"key_\", \"lastvalue\", \"error\"], \"hostids\": [\"$H\"]}" | jq -r '.[] | [.key_, .lastvalue, .error] | @tsv'
```

The truth is the load's own count: `kubectl -n podinfo logs deploy/load
--tail 2` (100 requests every ~32 s).

## Traps

| You see | Cause |
| --- | --- |
| a value that only goes up | *Change per second* missing: a counter's value means nothing |
| `Preprocessing failed … cannot find …` on `5xx per second` | no series matches — podinfo restarted, and has not answered a 500 yet. A pattern that matches nothing is an **error**, not 0, even with `sum` |
| the pattern refused at *Test* | quotes: `{status="200"}`, double quotes, as in the raw text |
| no value after a podinfo restart, for one interval | a counter went down: *Change per second* discards that value instead of storing a negative rate |

## Questions

- One request feeds all these items. What does that save, on the proxy
  and on podinfo, compared with one HTTP item each? What happens to all of
  them when the master fails? (Try it: `kubectl -n podinfo scale
  deploy/podinfo --replicas=0` for a minute, then back to 1. On the dry run
  every item went *unsupported* with the master's error, `Failed to
  connect to podinfo.podinfo.svc:9898`, and **no problem** was raised.)
- `5xx per second` is unsupported until the first 500: would you set
  *Custom on fail → Set value to 0* on that step? What could it hide?
- The mean latency is ~0.1 s. Is podinfo fast? (Step 3.)
