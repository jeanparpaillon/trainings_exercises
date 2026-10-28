# Step 6 — promote and roll back

**Slide:** Lab — step 6: promote and roll back · **~25 min**

dev runs a new image; prod does not. Promoting it is a pull request that
copies one line — `newTag` — from `envs/dev/` to `envs/prod/`, approved by
someone else.

From this step on, **`main` is protected** (the trainer turns it on): every
change goes through a pull request with one approval, and changes under
`envs/prod/` need the approval of a **code owner**. `git push` to `main` is
refused.

## Who approves prod

```sh
$EX/module6/copy step6-promote
cd $REPO
$EDITOR .github/CODEOWNERS            # your partner's GitHub login
git switch -c promote-workflow
git add .github && git commit -m "prod: code owners, promote workflow"
git push -u origin promote-workflow
gh pr create --fill
```

Any approval merges this one (CODEOWNERS only covers `envs/prod/`): ask
your partner, merge, `git switch main && git pull`.

## Promote

```sh
gh workflow run promote.yaml          # or Actions → promote → Run workflow
gh pr list                            # "prod: <tag>"
```

Your partner reviews it (one line, the same tag dev runs) and approves;
you merge. Then:

```sh
flux -n "$NS" reconcile source git f021
kubectl -n "$NS" rollout status deploy/wordpress-prod
```

prod's banner shows dev's tag. Nothing was rebuilt: compare
`kubectl -n "$NS" get pods -l app=wordpress -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}'`
— same digest in both environments.

## A bad release

A colleague adds audience tracking to the banner, in prod only:

```sh
git switch -c tracking main
$EX/module6/copy step6-promote/broken
git commit -am "banner: audience tracking in prod" && git push -u origin tracking
gh pr create --fill
```

Approve and merge it, then the `dev: <tag>` pull request the pipeline
opens. dev looks fine. Promote it to prod (`gh workflow run promote.yaml`,
partner approves, merge).

```sh
curl -s -o /dev/null -w '%{http_code}\n' http://wordpress.$NS.195.35.2.222.nip.io/
kubectl -n "$NS" get deploy wordpress-prod        # 2/2 ready
```

prod answers 500 on every page, and the rollout says all is well.

## Roll back

First the reflex:

```sh
kubectl -n "$NS" rollout undo deploy/wordpress-prod
```

Wait a minute (`flux -n "$NS" get kustomizations`, then the banner): how
long did it last?

Then the GitOps way — revert the promotion:

```sh
git switch main && git pull
git log --oneline -3 -- envs/prod/                 # the merge of "prod: <tag>"
git switch -c rollback-prod
git revert -m 1 <that merge commit>
git push -u origin rollback-prod && gh pr create --fill
```

Partner approves, merge: prod is back on the previous tag. Then fix the
code (revert the `tracking` pull request too, or fix the plugin), and let
the fix come through dev and a promotion like any other change.

## Questions to answer before moving on

- Why did dev not show the bug? What does that say about dev and prod
  configuration?
- Why did the rollout complete with every page answering 500? What should
  the readiness probe check instead (module 3)?
- `git log envs/prod/`: who promoted what, approved by whom? Where else
  would you find it with the push way?
