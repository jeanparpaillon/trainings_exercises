# Step 2 — deploy from CI, the push way

**Slide:** Lab — step 2: deploy from CI, then Lab — challenges · **~25 + 15 min**

Where most teams start, and where the DevOps training ended: the pipeline
builds the image, then runs `kubectl apply` against the cluster. For that,
the runner needs credentials for your namespace.

## A deploy identity for the runner

```sh
kubectl -n "$NS" apply -f $EX/module6/step2-push/ci-deployer.yaml
$EX/module6/step2-push/ci-kubeconfig > /tmp/kc
(cd $REPO && gh secret set KUBECONFIG_DEV < /tmp/kc)
rm /tmp/kc
```

Read [`ci-deployer.yaml`](ci-deployer.yaml) and
[`ci-kubeconfig`](ci-kubeconfig): what can this token do, from where, and
for how long?

## The deploy job

```sh
$EX/module6/copy step2-push        # .github/workflows/image.yaml, with a `deploy` job
git -C $REPO diff
```

Then make a code change, so that there is something to deploy: change
`$colour` in `app/f021-banner.php`.

```sh
cd $REPO
$EDITOR app/f021-banner.php
git commit -am "banner: new colour" && git push
gh run watch                   # or the Actions tab
```

`image` builds and pushes `ghcr.io/<owner>/f021-$NS:<tag>`, `deploy`
applies `envs/dev` with that tag. The first run creates everything: MySQL
needs a minute to initialise.

## Validate

```sh
kubectl -n "$NS" get deploy,sts,ingress -l env=dev
kubectl -n "$NS" rollout history deploy/wordpress-dev
```

Open `http://wordpress-dev.$NS.195.35.2.222.nip.io/`, install WordPress
(any title and admin password), and look at the bottom of the page: the
banner says `dev · <tag>`.

## Now break it — the challenges

In pairs, on each other's namespace if you like. For each row, answer the
question before moving on:

| Try this | Then ask |
| --- | --- |
| `kubectl -n "$NS" scale deploy wordpress-dev --replicas=0` | Who notices? When is it fixed? |
| `git log -p envs/dev/` | Which commit says which tag runs in dev? |
| Deploy **prod** | Which credentials does the runner hold then? Who approves? |
| Add a probe in `k8s/base/` | Who deploys it to each env, with which tag? |
| `kubectl -n "$NS" rollout undo deploy/wordpress-dev` | Is it in git? What does the next push do? |
| "What ran in prod on March 3rd?" | Where do you read the answer? |

Scale dev back to 1 when done:
`kubectl -n "$NS" scale deploy wordpress-dev --replicas=1`.

Keep the workflow: step 3 replaces its `deploy` job.
