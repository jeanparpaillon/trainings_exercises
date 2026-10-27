# Expose and reach your application

On WordPress, as the storage lab left it (`storage/step3-statefulset`: MySQL
as a StatefulSet): names from the inside, an HTTPRoute from the outside,
three ways to break a Service, and a first default-deny NetworkPolicy.

```sh
export NS=<your-namespace>
cd module2                       # every path below is relative to it
kubectl -n "$NS" get pods,svc,ingress    # wordpress, mysql-0; Services wordpress, mysql, mysql-headless
```

| | Step | Slide | ~ |
| --- | --- | --- | --- |
| 1 | [names, from the inside](step1-dns/) | Lab — network: names | 15 min |
| 2 | [an HTTPRoute](step2-gateway/) | Lab — network: Gateway API | 15 min |
| 3 | [break it](step3-break/) | Lab — network: break it | 20 min |
| 4 | [default deny](step4-netpol/) | Lab — network: default deny | 20 min |

Each step is a kustomize overlay on the previous one, step 1 on
`storage/step3-statefulset`: the WordPress Secret (module 1) and the
rendered Ingress must exist, as for the storage lab.

**Clean up after step 4**: delete the NetworkPolicies (see step 4). The
next modules assume an open namespace; module 5 comes back to them.
