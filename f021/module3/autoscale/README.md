# Measure, right-size, autoscale

Give Bookinfo correct requests and limits, and an HPA that reacts to load —
with before / after numbers. Six cumulative kustomize overlays on Bookinfo
as module 1 left it (`module1/lab1/step3-balancing`).

```sh
export NS=<your-namespace>
cd module3                                   # every path below is relative to it
kubectl -n "$NS" scale deploy/wordpress sts/mysql --replicas=0   # frees quota
```

WordPress comes back at the end of the lab (`--replicas=1`). The namespace
quota is **1 CPU requested**: the HPAs here stop at 3 replicas for that
reason, and `kubectl -n "$NS" describe quota` is the first thing to read if
a pod is missing.

## The benchmark

One k6 Job, the same for every step: 1 → 30 requests per second over 3
minutes, then 1 minute at 30.

```sh
kubectl -n "$NS" delete job k6 --ignore-not-found
kubectl -n "$NS" apply -f autoscale/k6/ramp.yaml
kubectl -n "$NS" logs -f job/k6              # med, p95, p99, failed ratio at the end
```

On the shared cluster the ramps are **staggered**: wait for your slot.
Keep a table — step, p50, p99, failed %, pods, CPU / memory at peak — and
fill one row per step.

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | `step1-baseline` | Lab — baseline | 10 min |
| 2 | `step2-cpu` | Lab — find the throttling | 15 min |
| 3 | `step3-memory` | Lab — find the OOM | 15 min |
| 4 | `step4-vpa` | Lab — right-size with VPA | 10 min |
| 5 | `step5-hpa-cpu` | Lab — HPA on CPU | 15 min |
| 6 | `step6-hpa-rps` | Lab — HPA on request rate | 10 min |

## Step 1 — baseline

```sh
kubectl -n "$NS" apply -k autoscale/step1-baseline
```

Run the ramp. Near the peak:

```sh
kubectl -n "$NS" top pods --containers
kubectl -n "$NS" get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
kubectl -n "$NS" get pod -l app=reviews -o jsonpath='{.items[0].spec.containers[0].resources}'
```

**Questions:** nobody wrote resources in Bookinfo — who set the ones you
see? (`kubectl -n "$NS" describe limitrange trainee`) Which QoS class do
the pods get, and why is none of them BestEffort?

## Step 2 — find the throttling

The baseline already has a CPU limit on `reviews`: the LimitRange default,
500m. Read its throttling during a ramp, in Grafana (*Explore*):

```promql
sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="<ns>", container="reviews"}[1m]))
/
sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="<ns>", container="reviews"}[1m]))
```

and compare with `kubectl top` at the same moment. Then apply the step —
an explicit request, and the limit raised to the LimitRange maximum — and
rerun:

```sh
kubectl -n "$NS" apply -k autoscale/step2-cpu
```

Also time a restart: `kubectl -n "$NS" rollout restart deploy/reviews-v2`
then `get pods -w`, with and without the step.

**Questions:** `kubectl top` showed `reviews` under 500m — why was it
throttled? Why can't the step simply remove the CPU limit? What still
stops `reviews` from taking the whole node?

## Step 3 — find the OOM

```sh
kubectl -n "$NS" apply -k autoscale/step3-memory
kubectl -n "$NS" get pods -l app=ratings -w      # during a ramp
kubectl -n "$NS" describe pod -l app=ratings | grep -A4 'Last State'
```

Part 1 — `ratings` has a memory limit too small for it. Find the exit
code, the reason, the restart count; then raise its request and limit in
`step3-memory/kustomization.yaml` to a value you can justify, re-apply.

Part 2 — `reviews` now has memory request = limit = 256Mi, and
`JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75`. Check the heap the JVM chose:

```sh
kubectl -n "$NS" exec deploy/reviews-v2 -c reviews -- \
  java -verbose:sizes -version 2>&1 | grep -i 'java heap'     # OpenJ9
```

**Questions:** why would `-Xmx256m` with a 256Mi limit be a guaranteed
OOMKill? Why memory request = limit, when step 2 did the opposite for CPU?

## Step 4 — right-size with VPA

```sh
kubectl -n "$NS" apply -k autoscale/step4-vpa
```

Run the ramp, wait a few minutes, then:

```sh
kubectl -n "$NS" get vpa
kubectl -n "$NS" describe vpa reviews-v2 | sed -n '/Recommendation/,$p'
```

**Questions:** what are `Lower Bound` and `Upper Bound` for? How much
history would you want before copying `Target` into the manifests? Why
not let the VPA apply it?

## Step 5 — HPA on CPU

```sh
kubectl -n "$NS" apply -k autoscale/step5-hpa-cpu
kubectl -n "$NS" describe hpa productpage       # before any load
```

Run the ramp and watch: `kubectl -n "$NS" get hpa productpage -w`. At the
end, watch the scale-down. Then uncomment `behavior` in
`step5-hpa-cpu/hpa.yaml`, re-apply, run the ramp again.

**Questions:** utilisation against what — usage, limit, request? How long
between the load arriving and a new pod serving? Which part of that delay
could you shrink?

## Step 6 — HPA on request rate

The step meshes `productpage` (Linkerd proxy, which counts requests) and
replaces the CPU HPA with one on `requests_per_second`, 10 per pod.

```sh
kubectl -n "$NS" apply -k autoscale/step6-hpa-rps
kubectl -n "$NS" get pods -l app=productpage     # 2/2: app + linkerd-proxy
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/$NS/pods/*/requests_per_second"
```

Run the ramp, compare with step 5: reaction time, pods at peak, p99.

**Questions:** the pod now has two containers. What would the step 5 HPA
(`type: Resource`) measure now — and why did the step have to give the
proxy a CPU request? Why is request rate a better signal than CPU for
`productpage`?

## Afterwards

```sh
kubectl -n "$NS" scale deploy/wordpress sts/mysql --replicas=1
kubectl -n "$NS" delete job k6 --ignore-not-found
```

Keep the rest: session 2 (harden the application) starts from here.
