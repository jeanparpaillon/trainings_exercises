# GitOps: WordPress through a pipeline

**Slides:** *CI/CD and GitOps for Kubernetes*, then *Lab — WordPress through
a pipeline* · **~3 h**, in two parts around the break

WordPress in two environments, **dev** and **prod**, side by side in your
namespace. GitHub Actions builds the image; first a job deploys it with
`kubectl` (the push way), then **Flux** takes over and git becomes the only
way in: deployments, promotions and rollbacks are pull requests.

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| | [setup](#setup) | Lab — setup | 10 min |
| 1 | [two environments](step1-envs/) | Lab — step 1 | 10 min |
| 2 | [deploy from CI, the push way, and its challenges](step2-push/) | Lab — step 2, challenges | 40 min |
| | *break* | | |
| 3 | [Flux takes over](step3-flux/) | Lab — step 3 | 20 min |
| 4 | [drift](step4-drift/) | Lab — step 4 | 10 min |
| 5 | [the pipeline: tag-bump pull request](step5-pipeline/) | Lab — step 5 | 30 min |
| 6 | [promote and roll back](step6-promote/) | Lab — step 6 | 25 min |
| 7 | [when the cluster says no](step7-alerts/) | Lab — step 7 | 25 min |

## Conventions

This lab works differently from the previous ones.

- **Your config repo.** The trainer created `https://github.com/<owner>/f021-<you>`
  for you (from [`repo/`](repo/)): the WordPress image (`app/`), its
  Kustomize base (`k8s/base/`) and one overlay per environment
  (`envs/dev/`, then `envs/prod/`). You clone it in your console; from
  step 3 on, nothing in your namespace is applied with `kubectl apply`: you
  commit, Flux reconciles.
- **Steps ship files to copy into your repo**, not overlays to apply.
  `$EX/module6/copy <step>` copies a step's `files/` into `$REPO`, with
  your namespace and the repo's owner filled in, and shows what changed.
  Read the diff before committing. You can also write them yourself: the
  copy is the solution.
- **Two environments in one namespace.** Every object of dev ends in
  `-dev` and carries `env: dev`, prod in `-prod` / `env: prod`. In real
  life: one namespace, or one cluster, per environment.
- **Pairs.** Your partner reviews your pull requests, you review theirs. From
  step 6, `main` is protected and prod changes need your partner's approval.
- **Variables**, set in the setup: `NS` (your namespace), `EX` (this
  `f021/` directory), `REPO` (your clone), `OWNER` (the repos' owner).

## Prerequisites

- a **GitHub account**, given to the trainer before the session; accept the
  invitation to your repo (e-mail, or `https://github.com/<owner>/f021-<you>/invitations`)
- a **classic personal access token** (*Settings → Developer settings →
  Personal access tokens → Tokens (classic)*), expiring after the session,
  with the scopes:

  | Scope | For |
  | --- | --- |
  | `repo` | clone and push, open pull requests, Flux's commit statuses (step 7) |
  | `workflow` | push changes to `.github/workflows/` |
  | `read:packages` | pull your images from GHCR into the cluster |
  | `read:org` | required by `gh auth login` |

  A fine-grained token does not work here: it cannot reach a repository
  owned by another user.

## Setup

**~10 min.** In your web console:

`gh` is in the console image from `f021-console:2` on; with an older
console, install it in your home first:

```sh
command -v gh || { mkdir -p ~/bin && curl -fsSL \
  https://github.com/cli/cli/releases/download/v2.63.0/gh_2.63.0_linux_amd64.tar.gz \
  | tar -xz -C ~/bin --strip-components=2 gh_2.63.0_linux_amd64/bin/gh; export PATH=~/bin:$PATH; }
```

```sh
cd <the exercises repo>/f021 && export EX=$PWD
export OWNER=<owner>                              # given by the trainer
export REPO=~/f021-$NS
gh auth login --with-token <<< '<your PAT>'       # then clear it from history
gh auth setup-git                                 # git uses that token
gh repo clone "$OWNER/f021-$NS" "$REPO"
git -C "$REPO" config user.name '<your name>'
git -C "$REPO" config user.email '<your GitHub e-mail>'
```

Put the four `export` lines in `~/.bashrc`: you will need them after a
console restart.

**Make room.** dev and prod together request ~500m CPU and ~1.4 GiB of
memory, out of the `trainee` quota's 1 CPU / 2 GiB. Remove the WordPress of
modules 2–4 (the Secret `wordpress-db` stays, both environments use it):

```sh
kubectl -n "$NS" delete --ignore-not-found \
  deploy/wordpress deploy/loadgen deploy/toolbox sts/mysql \
  svc/wordpress svc/mysql svc/mysql-headless ingress/wordpress httproute/wordpress \
  podmonitor/mysql prometheusrule/wordpress cm/wordpress-dashboard cm/wordpress-db
kubectl -n "$NS" delete pvc data-mysql-0 --ignore-not-found
kubectl -n "$NS" describe quota trainee
```

If Bookinfo still runs (modules 1 and 3), delete it as well, with `kubectl
delete -k` on the last step you applied (`module3/harden/step…`, or
`module1/lab1/step3-balancing`).

**Two Secrets, by hand, never in git:**

```sh
# the database password, from module 1 — create it again only if it is gone
kubectl -n "$NS" get secret wordpress-db \
  || kubectl -n "$NS" create secret generic wordpress-db \
       --from-env-file=module1/wordpress/step2-config/db.env

# pulling from GHCR: your packages are private
kubectl -n "$NS" create secret docker-registry ghcr \
  --docker-server=ghcr.io --docker-username=<your GitHub login> \
  --docker-password='<your PAT>'
```

**Look around:**

```sh
cd $REPO
cat README.md
kubectl kustomize envs/dev | less
gh run list                     # the trainer's first build of the image
```

Nothing runs yet: deploying is what step 2 is about.

## End state, starting over

At the end, both environments run from git, in your namespace, and stay
there. To catch up from scratch, or after the session: the trainer can
recreate a repo; `kubectl -n "$NS" delete deploy,sts,svc,ingress,cm -l env`
plus `pvc -l env` removes both environments (suspend the Kustomizations
first, or Flux recreates them within a minute).

---

## Trainer

**Before the session** (from `shared-cluster/`; needs `gh` logged in as
`GITHUB_OWNER`):

1. `secrets/github-logins` (git-ignored), one line per trainee:
   `<name> <github-login>`. Every trainee gets write access to every repo,
   so anyone can review, and be a code owner, on anyone else's.
2. `make config-repos` (or `NAMES="user1 user2"`): for each trainee,
   creates `$GITHUB_OWNER/f021-<name>` from [`repo/`](repo/) (namespace
   rendered in; dev's `newTag` set to the tag the first build will push),
   lets Actions open pull requests, invites every trainee,
   and starts the first image build. Existing repos are skipped.
   `VISIBILITY=public` if the owner's plan cannot protect branches of
   private repos (step 6).
3. `make deploy-keys` (or `NAMES=…`): Flux's read-only key on each repo.
4. Check that each first build went through: `gh run list -R
   $GITHUB_OWNER/f021-<name>`. The Trivy gate fails the build on a fixable
   critical vulnerability of the WordPress image: bump `FROM` in
   `repo/app/Dockerfile` if it does.

**Step 3**: `make enable-flux` (or `NAMES=…`) uncomments the trainees' Flux
tenants in `tenants/kustomization.yaml`; commit, push, `flux reconcile
kustomization tenants --with-source`.

**Step 6**: `make protect-repos` (or `NAMES=…`): branch protection on
`main`, one approval, code owners' review required.

**After the session**: delete the repos and their packages (`gh repo delete`,
and the packages in the owner's *Packages* tab), and the trainees' tokens
expire on their own.

Things that go wrong:

- **ImagePullBackOff**: the `ghcr` Secret is missing or the PAT lacks
  `read:packages`; or the package is not linked to the repo (the build
  labels it with `org.opencontainers.image.source` for that). Making the
  package public (*Package settings*) unblocks a trainee.
- **The deploy job cannot reach the API**: GitHub-hosted runners come from
  Azure address ranges; port 6443 must be open to them.
- **`bump-dev` cannot open the pull request**: *Settings → Actions → General
  → Allow GitHub Actions to create and approve pull requests* (set by
  `make config-repos`).
- **The trainee cannot push workflow files**: PAT without `workflow`.
