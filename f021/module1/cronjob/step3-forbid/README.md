# Step 3 — a run longer than the schedule

**Slide:** Exercise — a CronJob in your namespace, questions 3–5 · **~5 min**

Each run now sleeps 90 s, with a tick every 60 s. Same change as editing
`sleep 10` into `sleep 90` and re-applying:

```sh
kubectl -n "$NS" apply -k cronjob/step3-forbid
kubectl -n "$NS" get cronjob hello -w          # ACTIVE stays at 1
kubectl -n "$NS" get jobs -w                   # in a second terminal
```

At the next minute, no new Job while one is running: with
`concurrencyPolicy: Forbid` the tick is skipped. The change only applies to
the **next** Job created: a Job already running keeps its 10 s.

Try the two other policies (edit `step2-cronjob/cronjob.yaml`, or
`kubectl patch`), a few minutes each:

```sh
kubectl -n "$NS" patch cronjob hello -p '{"spec":{"concurrencyPolicy":"Allow"}}'
kubectl -n "$NS" patch cronjob hello -p '{"spec":{"concurrencyPolicy":"Replace"}}'
```

## Suspend, then clean up

```sh
kubectl -n "$NS" patch cronjob hello -p '{"spec":{"suspend":true}}'
kubectl -n "$NS" get cronjob hello             # SUSPEND True, no new Job
kubectl -n "$NS" delete -k cronjob/step3-forbid
kubectl -n "$NS" delete job now --ignore-not-found
```

Do not leave it running: it would create a pod every minute all week.

## Questions to answer before moving on

- With `Allow`, how many runs are active after 5 minutes? What would a
  slow nightly job do to the namespace quota?
- With `Replace`, what happens to a run that was half done? What does that
  ask of the job's code?
- A CronJob can miss a tick, or rarely create two Jobs for one. What must
  be true of the work for that not to matter?
