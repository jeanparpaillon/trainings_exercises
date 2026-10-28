# Step 3 — Flux takes over

**Slide:** Lab — step 3: Flux takes over · **~20 min**

The trainer — the platform team — enables your **Flux tenant** in the fleet
repo (`shared-cluster/tenants/<you>-flux.yaml`):

- a ServiceAccount `flux` with `edit` in your namespace: what Flux applies
  with, no more than you
- a `GitRepository` `f021` on your config repo, through a read-only deploy
  key
- two `Kustomization`s, `wordpress-dev` on `./envs/dev` and `wordpress-prod`
  on `./envs/prod`: every minute, render the overlay, apply it, delete what
  left git (`prune`), wait until it is healthy (`wait`)

Meanwhile, take the cluster away from the runner.

## 1. Put the running tag in git

The deploy job set the tag in the runner's checkout, never in a commit:
`envs/dev` still says `0000000`. If Flux applied it as is, dev would go back
to that image.

```sh
kubectl -n "$NS" get deploy wordpress-dev -o jsonpath='{..image}{"\n"}'
cd $REPO
$EDITOR envs/dev/kustomization.yaml          # newTag: that tag
```

From now on, this file is the only place a tag is written.

## 2. Remove the deploy job and its credentials

```sh
$EDITOR .github/workflows/image.yaml         # delete the whole `deploy` job
git commit -am "dev: the running tag; no more kubectl in CI" && git push
gh secret delete KUBECONFIG_DEV
kubectl -n "$NS" delete -f $EX/module6/step2-push/ci-deployer.yaml
```

(The workflow as it should be now is [`../repo/.github/workflows/image.yaml`](../repo/.github/workflows/image.yaml).)

## 3. Watch

```sh
flux -n "$NS" get sources git
flux -n "$NS" get kustomizations --watch
kubectl -n "$NS" get deploy,sts -L env
```

- `wordpress-dev` is **taken over** in place: same objects, same pods — Flux
  applies server-side what `kubectl apply` had created.
- `wordpress-prod` is **created**: the first deployment of prod, and nobody
  ran a command. Open `http://wordpress.$NS.195.35.2.222.nip.io/` and install
  it (prod has its own database).

## Validate

```sh
flux -n "$NS" get kustomizations             # both Ready, on your last commit
gh secret list                               # no KUBECONFIG_*
kubectl -n "$NS" get sa                      # no ci-deployer
kubectl auth can-i --list -n "$NS" --as=system:serviceaccount:$NS:flux | head
```

## Questions to answer before moving on

- `kubectl -n "$NS" edit kustomization wordpress-prod`, set `suspend: true`:
  what happens within a few minutes? Who owns that object?
- The pipeline is green and pushed nothing to the cluster. How does a new
  image reach dev now? (Step 5.)
- Which firewall rule did the push way need, that this one does not?
