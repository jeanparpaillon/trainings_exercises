# Step 4 — drift

**Slide:** Lab — step 4: drift · **~10 min**

Flux applies git every minute, whether git changed or not. What does that
do to changes made by hand? `flux reconcile` saves waiting for the interval.

```sh
alias fr='flux -n "$NS" reconcile kustomization'
```

## A field git sets

```sh
kubectl -n "$NS" scale deploy wordpress-prod --replicas=0
fr wordpress-prod
kubectl -n "$NS" get deploy wordpress-prod             # 2 again
```

```sh
kubectl -n "$NS" get cm -l env=prod                    # the generated name
kubectl -n "$NS" edit cm <that name>                   # env: hacked
fr wordpress-prod
```

The ConfigMap is restored. The running pods read it at start: did they
ever see `hacked`?

## An object git does not know

```sh
kubectl -n "$NS" create configmap scratch --from-literal=a=b
fr wordpress-dev
kubectl -n "$NS" get cm scratch                        # still there
```

Flux deletes only what it created: its inventory is in the Kustomization's
status (`kubectl -n "$NS" get kustomization wordpress-dev -o yaml`).

## A file removed from git

Add a ConfigMap to dev through git, then remove it:

```sh
cd $REPO
kubectl -n "$NS" create configmap drift-test --from-literal=a=b \
  --dry-run=client -o yaml > envs/dev/drift-test.yaml
$EDITOR envs/dev/kustomization.yaml     # resources: add drift-test.yaml
git add envs/dev && git commit -m "dev: drift test" && git push
fr wordpress-dev --with-source && kubectl -n "$NS" get cm drift-test-dev

git rm envs/dev/drift-test.yaml
$EDITOR envs/dev/kustomization.yaml     # remove it from resources
git commit -am "dev: no drift test" && git push
fr wordpress-dev --with-source && kubectl -n "$NS" get cm drift-test-dev   # NotFound: pruned
```

## The emergency fix

An incident at 3 a.m.: you must change prod *now*, by hand.

```sh
flux -n "$NS" suspend kustomization wordpress-prod
kubectl -n "$NS" scale deploy wordpress-prod --replicas=3     # the "hotfix"
flux -n "$NS" resume kustomization wordpress-prod
kubectl -n "$NS" get deploy wordpress-prod                    # ?
```

| Change | Flux |
| --- | --- |
| a field git sets | reverted |
| an object git does not know | ignored |
| a file removed from git | pruned |
| anything, while suspended | nothing — until resume |

## Questions to answer before moving on

- What must happen *between* `suspend` and `resume`, for the hotfix to
  survive?
- With an HPA on prod (module 3), who wins `replicas`? What must the overlay
  not set?
