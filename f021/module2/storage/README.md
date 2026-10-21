# Persistent storage and StatefulSet

Continues the WordPress lab of module 1 (`module1/wordpress/step2-config`):
the ConfigMap, the Secret `wordpress-db` and your rendered Ingress must
exist. Every path below is relative to `module2/`.

```sh
export NS=<your-namespace>
cd module2
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [a claim for MySQL](step1-pvc/) | Lab — storage: a claim for MySQL | 20 min |
| 2 | [scale both tiers](step2-scale/) | Lab — storage: scale up | 15 min |
| 3 | [MySQL as a StatefulSet](step3-statefulset/) | Lab — storage: StatefulSet | 20 min |

Quota: step 2 runs two MySQL and three WordPress next to Bookinfo, close to
the namespace's `limits.memory` (4Gi). If a pod is missing, look at
`kubectl -n "$NS" describe quota` and the ReplicaSet events
(`FailedCreate ... exceeded quota`).
