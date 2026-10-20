# Step 1 — cluster `mon`, Zabbix credentials, `~/m3`

**Slides:** *One proxy per cluster* · **~10 min**

The room has one Zabbix server. On it, the trainer created your tenant:
a proxy, a host group, a template group and a user, all named after your
console login, and a PSK that only your proxy knows. Your console reads
them from a Secret of the shared cluster.

## Your credentials

```sh
cd ~/trainings_exercises/f021bis/module3
make -C lab0 credentials        # ~/.zabbix/user.env, ~/.zabbix/user.psk
source versions.env
source ~/.zabbix/user.env
make -C lab0 check              # every line ok, the trapper open, the API answers
```

Read `~/.zabbix/user.env` (but do not paste the password anywhere):

| Variable | What it is |
| --- | --- |
| `ZBX_USER` | your login on the frontend, your proxy's name, your PSK identity |
| `ZBX_PASSWORD` | your frontend password |
| `ZBX_PSK_FILE` | the PSK, a file in `~/.zabbix/`, mode 600 |
| `ZBX_SERVER` | the server's trapper, **an IP**: the server's host name resolves to `127.0.1.1` inside every container on the server |
| `ZBX_URL` | the frontend, in your browser |
| `ZBX_API` | the API, from the console (`lab0/zapi` uses it) |
| `CLUSTER` | `mon-<name>`, your cluster for the four labs |

Both files are outside the repo and outside `~/m3`: nothing secret goes
into Git.

## The cluster

```sh
kind create cluster --name "$CLUSTER" --config lab1/kind.yaml --image "$KIND_NODE"
kubectl config current-context        # kind-mon-<name>
kubectl config set-context --current --namespace default
make -C lab0 load                     # the module's images into both nodes
kubectl get nodes -o wide             # note the two INTERNAL-IPs: step 4
```

The `set-context` line matters in a console: kind's context has no
namespace, and `kubectl` running **in a pod** then falls back to the pod's
own namespace, `consoles` — `kubectl get pods` in your cluster would look
in a namespace that does not exist there.

`make -C lab0 load` is `docker save --platform linux/amd64` then `kind
load image-archive`: plain `kind load docker-image` fails with this Docker
(`ctr: content digest sha256:…: not found`).

## The frontend

Open `$ZBX_URL` in your browser, log in as `$ZBX_USER`.

- *Data collection → Host groups*: your group `<name>`, empty. The other
  trainees' groups are there too.
- *Administration → Proxies*: your proxy `<name>`, never seen yet.
- *Data collection → Templates*, group `Templates/Operating systems`: the
  shipped templates, which you can link but not edit.

The same, without the UI:

```sh
lab0/zapi proxy.get '{"output": ["name", "state", "lastaccess"]}' | jq .
```

## `~/m3`

```sh
git init ~/m3
```

Everything you make on the server ends up there, as exports, by the end of
each lab.

## Questions

- What can user `<name>` see of the other trainees, what can it change, and
  why is that enough isolation for a lab and not for production (one
  server, one database, one `Admin`)?
- Why is the cluster `mon-<name>` and not just `mon`? (Lab 2: host names are
  unique on the server, and discovered hosts are named after the nodes.)
