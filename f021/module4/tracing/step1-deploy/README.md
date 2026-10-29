# Step 1 — deploy and look

**Slide:** Lab — tracing: deploy and look · **~10 min**

Two Deployments and their Services, and one Ingress with two host names:

- [`jaeger.yaml`](jaeger.yaml): Jaeger all-in-one, OTLP in on 4317 / 4318,
  the UI on 16686;
- [`hotrod.yaml`](hotrod.yaml): HotROD, sending its spans to
  `http://jaeger:4318` — read the `env`: which variable says where?
- [`ingress.yaml.tmpl`](ingress.yaml.tmpl): `hotrod.<ns>…` and
  `jaeger.<ns>…`.

```sh
sed "s/CHANGEME/$NS/g" tracing/step1-deploy/ingress.yaml.tmpl \
  > tracing/step1-deploy/ingress.yaml
kubectl -n "$NS" apply -k tracing/step1-deploy
kubectl -n "$NS" get pods -l 'app in (jaeger,hotrod)'     # both 1/1
```

In your browser:

- HotROD: `http://hotrod.<ns>.195.35.2.222.nip.io/` — click a few
  customers to order rides. Each line it prints has a *find trace* link.
- Jaeger: `http://jaeger.<ns>.195.35.2.222.nip.io/`
- Grafana: `https://grafana.srv2052563.hstgr.cloud/` — the data source
  **Jaeger &lt;ns&gt;** is already there, provided by the platform; it
  reads the Jaeger you just deployed.

## Look

In Grafana — where the metrics of the monitoring lab already are:

1. **Explore** → data source **Jaeger &lt;ns&gt;** → *Query type* Search →
   *Service* `frontend`, *Operation* `GET /dispatch` → *Run query*. Click
   a trace ID: the trace opens in a split pane.
2. Unfold the waterfall: each line is a span, indented under its parent.
   Click one: its *Span attributes*, its *Resource attributes*
   (`service.name`…), its *Events*.
3. Above the waterfall, **Node graph**: the services this one trace went
   through, and the time spent in each.

In the Jaeger UI, the same traces, plus one thing Grafana does not have:
**System Architecture** (top menu), the service graph of *all* the
traces, drawn from them alone.

`mysql` and `redis-manual` are not real servers: HotROD simulates them,
and reports them as services of their own, as a database instrumented on
the client side would show up.

## Questions to answer before moving on

- How many **services** does one click go through? Which one calls which?
- Which span is the **root**? What is its kind (`SERVER`, `CLIENT`)?
- In `frontend`, find the `HTTP GET` span that calls `customer`, and the
  `GET /customer` span on the customer side. Why two spans for one call,
  and what is the difference in their durations?
- Where did HotROD's trace context travel between `frontend` and
  `customer`? (Slide *Propagation*.)
