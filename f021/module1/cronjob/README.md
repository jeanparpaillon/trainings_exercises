# Jobs and CronJobs

**Slides:** *Jobs and CronJobs*, then *Exercise — a CronJob in your
namespace* · **~15 min**

One Job that succeeds and one that fails, then a CronJob: its history, a
manual run, a run longer than its schedule.

```sh
export NS=<your-namespace>
cd module1                         # every path below is relative to it
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [a Job](step1-job/) | A Job: run to completion · When a Job fails | 5 min |
| 2 | [a CronJob](step2-cronjob/) | Exercise — a CronJob in your namespace (1–2, 4) | 5 min |
| 3 | [a run longer than the schedule](step3-forbid/) | Exercise — a CronJob in your namespace (3, 5) | 5 min |

Step 3 is an overlay on step 2. Step 1 is plain manifests: a finished Job
is deleted and recreated, not updated.

**Clean up at the end of step 3**: the CronJob runs every minute.
