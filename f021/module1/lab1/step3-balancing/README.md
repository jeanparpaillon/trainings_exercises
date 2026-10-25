# Step 3 — round-robin across the reviews versions

**Slide:** Lab 1 — round-robin across reviews versions · **~10 min**

Adds `loadgen`: one request per second against `productpage`, forever, so
that there is always some traffic to look at. Module 3 stops it and uses
k6 instead.

```sh
kubectl -n "$NS" apply -k lab1/step3-balancing
```

## Watch the traffic spread

Reload `/productpage` in the browser repeatedly, or from the toolbox:

```sh
kubectl -n "$NS" exec deploy/toolbox -- sh -c \
  'for i in $(seq 1 12); do wget -q -O - http://reviews:9080/reviews/0 | head -c 120; echo; done'
```

Roughly a third of the responses come from each version: no ratings (v1),
black stars (v2), red stars (v3).

Where the balancing happens:

```sh
kubectl -n "$NS" get endpoints reviews -o wide
```

kube-proxy programmes those three endpoints into iptables (or IPVS) rules on
every node, and picks one **per new connection**. Nothing in the application
chose this.

## The catch

Per-connection is not per-request. With HTTP/1.1 and a fresh connection each
time, the distribution looks fair. With one long-lived connection — HTTP/2,
gRPC, a client with keep-alive — every request on that connection lands on the
same pod, and the balancing silently stops.

```sh
# one connection, many requests: watch it stick
kubectl -n "$NS" exec deploy/toolbox -- sh -c \
  'wget -q -O - --header="Connection: keep-alive" http://reviews:9080/reviews/0 | head -c 60'
```

This is the problem an L7 proxy fixes — a service mesh, or Gateway API
routes — by balancing per request.

## Note what this is *not*

Running three versions behind one Service is a deployment pattern, not a
release strategy. Nothing here lets you say "10% to v3" — the split is
whatever the endpoint list happens to be. Getting that control takes an L7
proxy again: weighted routes (deployment strategies, module 6).

## Questions to answer before moving on

- Scale `reviews-v3` to 3 replicas. What happens to the split, and is that
  what you wanted?
- How would you ship a new version to 10% of users with only the objects you
  have right now?
