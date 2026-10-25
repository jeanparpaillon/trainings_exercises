# Step 1 — a Job

**Slides:** A Job: run to completion · When a Job fails · **~5 min**

Plain manifests, applied with `-f`: a Job is not something you re-apply
to update.

## Success

```sh
kubectl -n "$NS" apply -f cronjob/step1-job/job.yaml
kubectl -n "$NS" get job,pods -l app=migrate -w     # Running, then Complete
kubectl -n "$NS" logs job/migrate
kubectl -n "$NS" wait --for=condition=complete job/migrate --timeout=60s
```

Apply it again: `unchanged`. The Job succeeded, there is nothing left to
do. To run it again, delete it first.

## Failure

```sh
kubectl -n "$NS" apply -f cronjob/step1-job/job-failing.yaml
kubectl -n "$NS" get pods -l app=migrate-failing -w   # 3 pods, Error, spaced out
kubectl -n "$NS" describe job migrate-failing | tail -8
kubectl -n "$NS" logs -l app=migrate-failing --prefix
```

Three pods, one per attempt, each with its logs, then the Job condition
`Failed`, reason `BackoffLimitExceeded`.

## Questions to answer before moving on

- How long between the attempts, and why does it grow?
- `migrate` has `activeDeadlineSeconds: 120`. What would it catch that
  `backoffLimit` does not?
- Wait 10 minutes, or read `ttlSecondsAfterFinished`: what happens to both
  Jobs? Without it, who would clean them up?
