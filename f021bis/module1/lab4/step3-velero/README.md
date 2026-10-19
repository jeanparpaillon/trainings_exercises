# Step 3 — Velero

**Slide:** Velero: backups at the object level · **~25 min**

## Where backups go

Outside the cluster: an S3 store as a container of your console's Docker,
next to the kind nodes. Read [`../s3/start`](../s3/start), then:

```sh
S3_URL=$(lab4/s3/start); echo "$S3_URL"
```

## Install Velero

```sh
velero install \
  --provider aws --plugins "velero/velero-plugin-for-aws:$VELERO_AWS_PLUGIN_VERSION" \
  --image "velero/velero:$VELERO_VERSION" \
  --bucket velero --secret-file lab4/s3/credentials-velero \
  --backup-location-config "region=us-east-1,s3ForcePathStyle=true,s3Url=$S3_URL" \
  --use-volume-snapshots=false --wait
velero backup-location get                       # PHASE Available
kubectl -n velero get pods
```

## Back up

```sh
velero backup create bookinfo --include-namespaces bookinfo --wait
velero backup describe bookinfo --details
```

Read `Phase` first — `Completed`, not `PartiallyFailed` — then the resource
list: what Velero saved, kind by kind.

Something that exists only after the backup:

```sh
kubectl -n bookinfo create configmap after-backup --from-literal=t="$(date +%T)"
```

## The disaster, again

```sh
kubectl delete ns bookinfo
stars                                            # 0
velero restore create bookinfo --from-backup bookinfo --wait
velero restore describe bookinfo
kubectl -n bookinfo rollout status deploy --timeout=5m
kubectl -n bookinfo get configmap after-backup
stars                                            # 9
```

No kubelet to restart this time: Velero went through the API, so every
controller saw the objects arrive. Fill the Velero row of the table.

## Questions

- An S3 store that refused signed requests gave a backup that said
  `PartiallyFailed` while this step was written. What would have caught it
  before the day you needed the backup?
- Which objects does Velero skip or change on restore? (Nodes, Events; the
  ClusterIP of Services; PV names.)
- Velero went through the API. What could it not restore that etcd could,
  and the other way round?
- Neither restore brought back anything *inside* a volume. What would it
  take for a namespace with a database? (`--use-node-agent`, and which
  PVs it can read.)
