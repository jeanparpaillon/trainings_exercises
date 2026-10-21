# WordPress + MySQL

Two services, one database: the core objects of a stateful application,
before storage (module 2) makes the data survive.

```
   user --- Ingress ---> wordpress ---> mysql
                         Deployment     Deployment
                         Service        Service (ClusterIP)
```

## Before you start

```sh
export NS=<your-namespace>
cd module1                       # every path below is relative to it
```

## The steps

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [deploy](step1-deploy/) | Lab — WordPress: deploy | 20 min |
| 2 | [configuration and secret](step2-config/) | Lab — WordPress: configuration and secret | 20 min |

Each step is a kustomize overlay on the one before it: `kubectl -n "$NS"
apply -k wordpress/step2-config` brings you to the end of step 2 from
anywhere (once its Secret exists, see step 2).

The module 2 storage lab continues from step 2.
