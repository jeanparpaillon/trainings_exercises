# WordPress — config repo of CHANGEME

Your copy of the F021 module 6 lab: WordPress, its image and its
environments. The lab instructions are in the exercises repo,
`f021/module6/README.md`.

| Path | What | Changes |
| --- | --- | --- |
| `app/` | the image: official WordPress + the `f021-banner` plugin | every code change |
| `k8s/base/` | how WordPress runs on Kubernetes | rarely |
| `envs/<env>/` | where, with which image tag and settings | every deployment |
| `.github/workflows/` | the pipelines | — |

- dev: http://wordpress-dev.CHANGEME.195.35.2.222.nip.io/
- prod: http://wordpress.CHANGEME.195.35.2.222.nip.io/ (from step 1)

```sh
kubectl kustomize envs/dev          # what dev runs, rendered
```
