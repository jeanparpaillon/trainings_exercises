# First deployment

**Slide:** Exercise — first deployment · **~45 min**

nginx in your namespace: deploy, expose, self-heal, scale, roll out, roll
back, configure. **You write the manifests yourself**, in a `k8s/` folder;
the step directories hold the solution, to compare with or to catch up.

```sh
export NS=<your-namespace>
cd module1                         # every path below is relative to it
mkdir -p first-deploy/k8s          # your manifests (git-ignored)
```

| | Step | Objectives | ~ |
| --- | --- | --- | --- |
| 1 | [deploy and expose](step1-deploy/) | 1–4: Deployment + Service, apply, reach it, self-healing | 15 min |
| 2 | [scale, roll out, roll back](step2-rollout/) | 5–6: 4 replicas, a new tag, a tag that does not exist | 15 min |
| 3 | [a ConfigMap as a file](step3-configmap/) | 7: the page nginx serves, out of the image | 15 min |

Lost, or want to compare? Each step is a kustomize overlay on the one
before it:

```sh
kubectl kustomize first-deploy/step2-rollout       # what the solution renders
kubectl -n "$NS" apply -k first-deploy/step2-rollout   # land at the end of step 2
```

## Expected result

- `kubectl -n "$NS" get deploy,rs,pods,svc` shows your application, all
  Ready
- `kubectl -n "$NS" rollout history deploy/web` lists 3 revisions or more
- you can explain why the broken rollout of step 2 caused no outage

## Cleanup

Nothing later depends on it; it only takes quota:

```sh
kubectl -n "$NS" delete -k first-deploy/step3-configmap
```
