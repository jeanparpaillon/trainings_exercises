# Monitoring your application

**Slides:** *Monitoring & reporting*, then *Lab — monitoring* · **~60 min**

Your WordPress in the room's Prometheus and Grafana: what the platform
already measures for you, the metrics your application has to add, alerts
and a dashboard — all as manifests next to the application. Four
cumulative kustomize overlays on WordPress as module 2 left it
(`module2/network/step2-gateway`); every path below is relative to
`module4/`.

```sh
export NS=<your-namespace>
cd module4
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [look: what is measured already](step1-look/) | Lab — monitoring: look | 15 min |
| 2 | [metrics: the database, and the edge](step2-metrics/) | Lab — monitoring: metrics | 15 min |
| 3 | [alerts: symptoms and causes](step3-alerts/) | Lab — monitoring: alerts | 20 min |
| 4 | [dashboard as code](step4-dashboard/) | Lab — monitoring: dashboard | 10 min |

**Grafana**: `https://grafana.srv2052563.hstgr.cloud/`, your console login
and password (role Editor). The whole room shares it: your namespace is in
every query, and in the name of everything you create.

**Prometheus** itself is not exposed: query it through Grafana
(*Explore*, data source *Prometheus*).

Keep the end state: the troubleshooting lab starts from
`monitoring/step4-dashboard`, and your alerts will fire during its
scenarios.
