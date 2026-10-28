# Step 1 — two environments

**Slide:** Lab — step 1: two environments · **~10 min**

Your repo has one environment, `envs/dev/`. Read its
[`kustomization.yaml`](../repo/envs/dev/kustomization.yaml) first, then write
`envs/prod/` yourself:

- name suffix `-prod`, label `env: prod` (with `includeSelectors`)
- its own database host (`mysql-prod:3306`) and `env=prod` in the ConfigMap
- **2 replicas** of WordPress
- host `wordpress.$NS.195.35.2.222.nip.io`
- the **same image tag** as dev (`newTag`): copy it

```sh
cd $REPO
mkdir -p envs/prod
$EDITOR envs/prod/kustomization.yaml
kubectl kustomize envs/prod | grep -E '^  name:|image:|host:'
```

Stuck, or to compare: [`files/envs/prod/kustomization.yaml`](files/envs/prod/kustomization.yaml),
copied in with `$EX/module6/copy step1-envs` (then set `newTag` by hand).

Compare the two **rendered** environments:

```sh
diff <(kubectl kustomize envs/dev) <(kubectl kustomize envs/prod)
```

Commit and push:

```sh
git add envs/prod && git commit -m "prod environment" && git push
```

Nothing deploys prod. Nothing has deployed dev either, yet: that is step 2.

## Questions to answer before moving on

- How many lines differ between the two rendered environments? Which ones
  will a promotion change?
- Remove `includeSelectors: true` from `envs/prod` and render: what does
  `service/wordpress-prod` select? (Put it back.)
- Why does each overlay set `host` in the ConfigMap itself, when
  kustomize already renamed `service/mysql` to `mysql-prod`?
