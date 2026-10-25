# Step 2 — a CronJob

**Slide:** Exercise — a CronJob in your namespace, questions 1–2 · **~5 min**

```sh
kubectl -n "$NS" apply -k cronjob/step2-cronjob
kubectl -n "$NS" get cronjob,jobs,pods -l app=hello -w     # for 3 minutes
```

Once a few have run:

```sh
kubectl -n "$NS" get cronjob hello            # SCHEDULE, LAST SCHEDULE, ACTIVE
kubectl -n "$NS" get jobs -l app=hello
kubectl -n "$NS" logs job/<one-of-the-jobs>   # the date, in the pod's time zone (UTC)
```

## Run it now, without waiting

The way to test a CronJob before trusting its schedule:

```sh
kubectl -n "$NS" create job --from=cronjob/hello now
kubectl -n "$NS" logs -f job/now
```

## Questions to answer before moving on

- How many finished Jobs stay around? Which field decides, and what is the
  default for failed ones?
- The job name ends with a number. What is it? (`date +%s`, divided by 60)
- `timeZone: Africa/Algiers`, yet `date` in the logs prints UTC. Which one
  decides *when* the Job runs, and which one is just the container's clock?
- Is the `now` Job counted in the history limit? Is it deleted with it?
