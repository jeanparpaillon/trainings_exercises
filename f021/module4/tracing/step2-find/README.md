# Step 2 — find the bottleneck

**Slide:** Lab — tracing: find the bottleneck · **~20 min**

Nothing to apply. A user says "booking a ride is slow when we are busy".
The metric would tell you *that* `/dispatch` is slow; the traces tell you
*where*, and *why*.

## Load

One request alone, then five at the same time, from your web console:

```sh
HOTROD=http://hotrod.$NS.195.35.2.222.nip.io

# alone
curl -s -o /dev/null -w '%{time_total}s\n' "$HOTROD/dispatch?customer=123&nonse=$RANDOM"

# five users at once
for c in 123 392 567 731 123; do
  curl -s -o /dev/null -w '%{time_total}s\n' "$HOTROD/dispatch?customer=$c&nonse=$RANDOM" &
done; wait
```

(`nonse` only makes each URL different; HotROD ignores it.) Run the second
command two or three times: the times climb from the first answer to the
last.

## Read the traces

Grafana → **Explore** → **Jaeger &lt;ns&gt;** → Search `frontend` ·
`GET /dispatch`, last 15 minutes → sort the table by *Duration*. Open the
longest; then, with *Split*, a trace of the request sent alone next to it.
(The Jaeger UI does the same: *Search*, sort by **Longest First**.)

For each of `mysql`, `redis-manual`, `route`:

- How long are its spans, and how many are there?
- Do they run **one after the other** or **side by side**?
- Open a span's *Events* (*Logs* in the Jaeger UI): is it working, or
  **waiting**?

## Questions to answer before moving on

- Which span is **longest** under load, and is it working or waiting?
  Why is it longer with five users than with one?
- Which calls run **one after the other** where they could run in
  parallel?
- Which spans have status **ERROR** (red), and what did the caller do
  next?
- `/dispatch` takes 2 s for the fifth user. Would **more CPU**, or **more
  replicas** of HotROD, bring that down? (Look at what the spans are
  doing while they are long.)
