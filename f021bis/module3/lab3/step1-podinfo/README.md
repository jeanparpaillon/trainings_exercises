# Step 1 — an application with `/metrics`

**Slides:** *Zabbix and the Prometheus stack* · **~10 min**

The Kubernetes templates see nodes, pods and controllers. They do not see
whether an application answers, how fast, or how often with an error.
podinfo publishes that in Prometheus format on `:9898/metrics`, like most
applications written for Kubernetes.

## podinfo and its load

```sh
helm install podinfo lab0/charts/podinfo-$PODINFO_CHART_VERSION.tgz \
  -n podinfo --create-namespace -f lab3/step1-podinfo/values.yaml --wait
kubectl apply -f lab3/load.yaml
kubectl -n podinfo get pods -o wide
```

(No chart in `lab0/charts/`: `make -C lab0 chart`.)

Read [`values.yaml`](values.yaml): **one replica**, kept off the control
plane. Why one is step 4's subject; why off the control plane is lab 4's
(the drill pauses the worker).

[`../load.yaml`](../load.yaml) is a pod sending ~3 requests per second to
the Service: 8 in 10 to `/`, one to `/status/500`, one to `/delay/1`
(answers after 1 s). Its log says how far it got:

```sh
kubectl -n podinfo logs deploy/load --tail 2
```

## The raw metrics

```sh
kubectl -n podinfo port-forward svc/podinfo 9898 >/dev/null &
curl -s localhost:9898/metrics | grep -v '^#' | grep -E '^http_'
curl -s localhost:9898/metrics | grep -E '^(go_goroutines|process_start_time_seconds) '
curl -s localhost:9898/metrics | wc -lc
kill %1
```

Find, and note the labels of each:

| Metric | Type | Labels |
| --- | --- | --- |
| `http_requests_total` | counter | `status` only |
| `http_request_duration_seconds` (`_bucket`, `_sum`, `_count`) | histogram | `method`, `path`, `status`, and `le` on the buckets |
| `go_goroutines`, `go_memstats_*` | gauges | none |
| `process_start_time_seconds` | gauge | none: when this process started |

`path` is the route, not the URL: `root`, `status`, `delay`, `healthz`,
`readyz`, `metrics` — `/status/500` and `/status/404` are both
`path="status"`. `healthz` and `readyz` are the kubelet's probes;
`metrics` will be Zabbix itself. ~260 lines, ~20 KB per read.

## Questions

- Which of these is worth an alert, which a graph, which nothing? (The Go
  runtime metrics: who would look at them, and when?)
- `http_requests_total{status="500"} 12`: is that a lot? What do you need
  besides the number?
- The histogram has `path` and `status`; the counter has only `status`.
  Which one would you use to count requests per path?
