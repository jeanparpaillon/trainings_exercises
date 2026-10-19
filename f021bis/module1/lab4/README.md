# Lab 4 — backup and restore

**Slides:** *Backup and restore*, then *Lab 4* · **~70 min**

Back `prod` up two ways and restore it — the whole cluster from an etcd
snapshot, then a namespace with Velero — and find out what each one does
**not** bring back.

| Step | | ~ |
| --- | --- | --- |
| [step1-etcd-snapshot](step1-etcd-snapshot/) | snapshot + PKI, out of the node | 10 min |
| [step2-etcd-restore](step2-etcd-restore/) | restore it, and everything that comes with it | 20 min |
| [step3-velero](step3-velero/) | backup, delete, restore a namespace | 25 min |
| [step4-schedule](step4-schedule/) | schedules, and the restore test | 5 min |
| [step5-migrate](step5-migrate/) | *optional*: Bookinfo to a new cluster | 10 min |

| File | What it is |
| --- | --- |
| [`s3/`](s3/) | an S3 store (SeaweedFS) as a container next to the kind nodes, for Velero |
| `backup/` | where you copy what comes out of the nodes (git-ignored) |

## Check every restore

| After… | namespace `bookinfo` back? | ConfigMap made after the backup back? |
| --- | --- | --- |
| etcd restore (step 2) | | |
| Velero restore (step 3) | | |

Start state: `prod` at the end of lab 3 (Bookinfo drain-safe). **End state**
(start of lab 5): the same, plus Velero. From nothing: `make catch-up-lab4`
in `module1/`.

```sh
cd ~/trainings_exercises/f021bis/module1
source versions.env
source lab0/etcdctl.sh
stars() { curl -s http://127.0.0.1:30080/productpage | grep -c glyphicon-star; }
stars                                            # 9
```
