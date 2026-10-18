# Step 7 — baseline under load

**Slides:** *Lab 3 — upgrade* · **~10 min**

Before upgrading anything: what does "no downtime" look like, measured?
Module 1 used k6; a `curl` loop is enough here and needs nothing.

## The workload

`web` from step 6, down to 2 replicas and a PDB that still allows one
disruption, behind a NodePort ([`web-nodeport.yaml`](web-nodeport.yaml),
30082):

```sh
kubectl scale deploy web --replicas=2
kubectl patch pdb web --type merge -p '{"spec":{"minAvailable":1}}'
kubectl apply -f ~/trainings_exercises/f021bis/module2/lab3/step7-baseline/web-nodeport.yaml
kubectl get pods -l app=web -o wide
kubectl get pdb web                          # ALLOWED DISRUPTIONS 1
```

`web` has a readiness probe: a pod receives traffic only once nginx answers.

## The load

[`load`](../load): one request every 0.2 s from the console — outside the
cluster, like users — alternately to the NodePort of `node1` and `node3`.
It prints only the failures, and a summary every minute.

```sh
~/trainings_exercises/f021bis/module2/lab3/load          # its own tab; Ctrl-C prints the summary
```

Leave it a minute: the baseline is **0 failed** (the very first second after
creating the Service may fail while kube-proxy programs it).

## Record where you start

```sh
kubectl version
kubectl get nodes -o wide
ssh node1 sudo /usr/local/bin/etcd --version | head -1
```

## Questions

- `node1` is in `kube_node` too (step 2): what would happen to `web` during
  the upgrade if it were not?
- The load goes to both nodes' NodePorts. A real user would go through a
  load balancer: what would it need to know about a node being drained?
