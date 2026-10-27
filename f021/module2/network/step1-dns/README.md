# Step 1 — names, from the inside

**Slide:** Lab — network: names · **~15 min**

Adds a `toolbox` pod (a busybox shell) next to WordPress and MySQL.

```sh
kubectl -n "$NS" apply -k network/step1-dns
kubectl -n "$NS" exec -it deploy/toolbox -- sh
```

Inside the pod:

```sh
cat /etc/resolv.conf                         # search list, ndots:5
nslookup wordpress                           # short name
nslookup wordpress.$NS                       # <svc>.<ns>
nslookup wordpress.$NS.svc.cluster.local     # FQDN
nslookup mysql                               # ClusterIP: one virtual IP
nslookup mysql-headless                      # headless: the pod IP itself
nslookup mysql-0.mysql-headless              # one pod of the StatefulSet, by name
wget -qO- http://wordpress/ | grep -o '<title>.*</title>'
nc -w 3 mysql 3306 | head -c 40; echo        # MySQL greets you with its version
```

`$NS` is not set inside the pod: type your namespace.

## Another namespace

Pick a neighbour's namespace (`kubectl get ns`) and call their WordPress —
then their **database**:

```sh
wget -qO- -T 3 http://wordpress.<their-ns>/ | grep -o '<title>.*</title>'
nc -w 3 mysql.<their-ns> 3306 | head -c 40; echo
```

Both answer: the pod network is flat, and a namespace separates **names**,
not **traffic**. Anyone in the cluster can open a connection to your
database; only its password stands in the way. Step 4 changes that for
your namespace.

## Endpoints

Out of the pod:

```sh
kubectl -n "$NS" scale deploy/wordpress --replicas=2
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=wordpress
kubectl -n "$NS" get pods -l app=wordpress -o wide        # same IPs
kubectl -n "$NS" scale deploy/wordpress --replicas=1
```

## Questions to answer before moving on

- `nslookup wordpress` from a pod in another namespace: what does it find?
- `nslookup www.google.com`: how many queries does the resolver send
  before the real one? (`ndots:5` and the search list)
- `mysql` and `mysql-headless` select the same pod. Why does one answer
  with a virtual IP and the other with the pod's own address? Which one
  does WordPress use, and why is that the right choice?
- Your neighbour's MySQL answered. What, apart from a password, protects
  it today?
