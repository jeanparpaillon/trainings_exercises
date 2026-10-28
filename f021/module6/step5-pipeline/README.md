# Step 5 — the pipeline

**Slide:** Lab — step 5: the pipeline · **~30 min**

The theory's pipeline, for real: CI builds and proves, then **proposes** the
deployment as a pull request. Merging it is the deployment; Flux does the
rest.

```text
push app/**
  └ image   : build ─ Trivy ─ push :<tag>
  └ bump-dev: newTag=<tag> in envs/dev ─ render ─ kubeconform ─ PR "dev: <tag>"
review ─ merge
  └ Flux: wordpress-dev rolls
```

## The workflows

```sh
$EX/module6/copy step5-pipeline
cd $REPO && git diff
```

- [`image.yaml`](files/.github/workflows/image.yaml): the `bump-dev` job
  replaces step 2's `deploy` — same `kustomize edit set image`, but
  committed, on a branch, as a pull request
- [`manifests.yaml`](files/.github/workflows/manifests.yaml): on any pull
  request touching `k8s/` or `envs/`, render both environments, validate
  them, comment the rendered diff

```sh
git add .github && git commit -m "pipeline: tag-bump PR on dev" && git push
```

## Run it

Change the banner again (`$colour`, or the text), push:

```sh
$EDITOR app/f021-banner.php
git commit -am "banner: …" && git push
gh run watch
gh pr list                                   # "dev: <tag>"
gh pr view bump/dev --web                    # or in the browser
```

Ask your partner to look at the pull request before you merge it: one line
in `envs/dev/kustomization.yaml`. Merge it (in the browser, or
`gh pr merge bump/dev --merge`), then:

```sh
flux -n "$NS" reconcile source git f021      # or wait a minute
flux -n "$NS" get kustomizations
kubectl -n "$NS" get pods -l env=dev -w
```

## Validate

- dev's banner shows the new tag; prod's does **not** — nothing promoted it
- `git pull && git log --oneline envs/dev/`: one commit per deployment of
  dev, each pointing to the build that made the image
- `flux -n "$NS" events --for Kustomization/wordpress-dev`

Now open a pull request yourself that changes `k8s/` or `envs/` (for
example dev's replicas to 2): `manifests` runs and comments the rendered
diff. Merge it or close it.

## Questions to answer before moving on

- The `manifests` workflow did not run on the bot's pull request. Why? What
  would make it run? (Hint: which token opened it.)
- Push two banner changes in a row before merging: how many pull requests?
  Which tag does dev get?
- Why does the image tag not change when you only edit `envs/`?
