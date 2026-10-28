# Step 7 — when the cluster says no

**Slide:** Lab — step 7: when the cluster says no · **~25 min**

With the push way, a failed deployment is a red job. With GitOps the
pipeline ends at the merge: it is green before the cluster has even seen
the change. Something has to bring the cluster's answer back.

## Commit statuses from Flux

```sh
kubectl -n "$NS" create secret generic github-token --from-literal=token=<your PAT>
sed -e "s/CHANGEME/$NS/g" -e "s/GHOWNER/$OWNER/g" \
  $EX/module6/step7-alerts/alerts.yaml.tmpl | kubectl -n "$NS" apply -f -
flux -n "$NS" get alert-providers
flux -n "$NS" get alerts
```

(`--from-literal` puts the token in your shell history: `history -d` it, or
use `--from-file`.)

Make any change through a pull request (dev's replicas, say), merge it:
the commit on `main` gets two more statuses next to the Actions checks,
`kustomization/wordpress-dev/…` and `kustomization/wordpress-prod/…`
(`gh api repos/$OWNER/f021-$NS/commits/main/statuses --jq '.[] | .context + " " + .state'`).

## A change the cluster refuses

MySQL needs more space. In a branch, raise the volume in the base:

```sh
cd $REPO && git switch main && git pull && git switch -c mysql-2gi
sed -i 's/storage: 1Gi/storage: 2Gi/' k8s/base/mysql.yaml
git commit -am "mysql: 2Gi" && git push -u origin mysql-2gi
gh pr create --fill
```

`manifests` is green: the schema is valid, and the rendered diff shows the
change in **both** environments. Your partner approves, you merge. Then:

```sh
flux -n "$NS" get kustomizations
flux -n "$NS" events --for Kustomization/wordpress-prod
kubectl -n "$NS" describe kustomization wordpress-dev | tail
```

| Where | Says |
| --- | --- |
| Actions | green |
| `flux get kustomizations` | `False` — `StatefulSet … spec.volumeClaimTemplates: … field is immutable` |
| commit status on GitHub | failure, per environment |
| the site | still the previous version, still answering |

Nothing broke in the cluster: Flux's dry-run refused the whole overlay,
and both environments stay on their last applied revision — they no longer
follow `main`. Any other change merged now is not applied either.

Fix it the GitOps way: revert the pull request (`git revert -m 1`, a pull
request, approval, merge) and watch both Kustomizations go back to Ready.

## Other "green pipeline, red cluster" cases

Try one if time allows, then revert it:

- an image tag that does not exist in `envs/dev` (`newTag: "deadbee"`):
  applied, but the rollout never finishes — `wait` times out, the old pods
  keep serving
- dev's replicas to 10: the `trainee` quota refuses the pods — the same
  timeout, with the reason in `kubectl describe rs`
- `kubectl -n "$NS" delete secret ghcr`, then a new tag: `ImagePullBackOff`

## Questions to answer before moving on

- Which environments broke, and why both at once? How would you stage a
  base change dev-first? (Theory: *What to rebuild?*)
- How do you actually give MySQL more space? (Hint: the claim, not the
  template — and does the `standard` StorageClass allow it?)
- Who should receive these notifications, besides a commit status?
