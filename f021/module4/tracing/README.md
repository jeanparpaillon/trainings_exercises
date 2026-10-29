# Tracing a request

**Slides:** *Tracing*, then *Lab — tracing* · **~40 min**

One click in an application, followed through four services: the call
graph, what is slow, what waits, what fails — read from the traces, not
from the code. Then fix it, and check with the traces again.

There is no tracing stack on the shared cluster, so the lab brings its own,
in your namespace:

- **HotROD**, Jaeger's demo application: a ride-booking app, four services
  (`frontend`, `customer`, `driver`, `route`) and a fake MySQL and Redis,
  instrumented with OpenTelemetry;
- **Jaeger** all-in-one: receives the spans in OTLP, keeps them in memory,
  serves the UI.

You read the traces in the room's **Grafana**, next to the metrics:
the platform provides one data source per trainee, **Jaeger &lt;ns&gt;**,
pointing at the Jaeger in your namespace. The Jaeger UI is there too.

Not WordPress: it is one service, so its traces have no chain to follow,
and PHP needs the OpenTelemetry extension compiled into the image.
Nothing of modules 1–2 is touched: the lab runs next to it. Every path
below is relative to `module4/`.

```sh
export NS=<your-namespace>
cd module4
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [deploy and look](step1-deploy/) | Lab — tracing: deploy and look | 10 min |
| 2 | [find the bottleneck](step2-find/) | Lab — tracing: find the bottleneck | 20 min |
| 3 | [fix and compare](step3-fix/) | Lab — tracing: fix and compare | 10 min |

Cleaning up, when you are done:

```sh
kubectl -n "$NS" delete -k tracing/step3-fix
```

The troubleshooting lab does not need any of it.
