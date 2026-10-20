# Step 4 — the nodes as hosts, by hand

**Slides:** *Monitoring nodes* · **~20 min**

What you do today for a server: one host per node, an agent interface, the
Linux template. Here the agent is the chart's DaemonSet, and the host is
monitored **by your proxy**.

## Two hosts

```sh
kubectl get nodes -o wide         # NAME and INTERNAL-IP of both nodes
```

*Data collection → Hosts → Create host*, twice:

| Field | Value |
| --- | --- |
| Host name | `mon-<name>-control-plane`, then `mon-<name>-worker` — the node names (`$CLUSTER-…`) |
| Templates | *Linux by Zabbix agent* (group *Templates/Operating systems*) |
| Host groups | `<name>` — the only one you can write |
| Interfaces | *Agent*, IP = the node's `INTERNAL-IP`, port `10050` |
| Monitored by | *Proxy*, `<name>` |

The hosts go to your proxy with its next configuration sync (10 s), and
the proxy polls the agents (passive checks).

## Data

*Monitoring → Latest data*, host group `<name>`. On a dry run the first
values came ~40 s after the hosts were created, and the template's
discovery rules (filesystems, network interfaces, block devices: interval
1 h) had run by themselves within 3 minutes — 43 items per host, then 108.
If they have not after 5 minutes: *Data collection → Hosts → Discovery*
of the host, select the rules, *Execute now*.

Without the UI — the agent, from the proxy pod:

```sh
P=deploy/zabbix-zabbix-helm-chart-proxy
for k in system.uptime system.cpu.num 'vm.memory.size[total]' system.hostname; do
  echo "$k: $(kubectl -n monitoring exec $P -- zabbix_get -s <worker IP> -k "$k")"
done
```

(A rare `ZBX_NOTSUPPORTED: … agent dropped connection`: run it again.)

Compare with the console and with the node:

```sh
nproc; free -b | head -2; cut -d' ' -f1 /proc/uptime
docker exec "$CLUSTER-worker" cut -d' ' -f1 /proc/uptime
```

Look for: memory, CPU count and uptime **identical** to the console's;
`system.hostname` the node's name; *Number of installed packages*
(`system.sw.packages.get`) *not supported* (`cannot obtain package information`). The agent's log has a
`failed to read request from <node IP>: EOF` every 10 s: the kubelet's TCP
liveness probe.

## On purpose: the server goes away

The buffer is for this: the proxy keeps collecting while the server is
unreachable, and sends later. Cut the proxy from the server, and only from
it — it still reaches the agents:

```sh
sed "s/SERVER_IP/${ZBX_SERVER%:*}/" lab1/step4-nodes/cut.yaml | kubectl apply -f -
kubectl -n monitoring logs deploy/zabbix-zabbix-helm-chart-proxy -f | grep -i connect   # Ctrl-C to stop
```

Wait two minutes (the proxy goes *offline*, step 3's `proxy.get`), then:

```sh
kubectl -n monitoring delete networkpolicy cut-server
```

On a dry run: `Unable to connect to […]: connection timed out` within
seconds, *offline* after 68 s, `Connection restored.` and *online* 7 s
after the policy was deleted. Then *Monitoring → Latest data*, an item of
the worker every 1 m (*Available memory*), *History*: **no gap** — the
values of the two minutes arrived late, with their own timestamps. No
problem was raised either.

## Questions

For the debrief:

- Whose kernel, memory and uptime are these? (The server's: a kind node is
  a container on it, and so is your console.)
- On your production nodes, what does the agent DaemonSet see that a
  package on the host would not, and the reverse? Which one still reports
  when the kubelet or the container runtime is dead?
- How would module 2's role install the agent as a package instead?
- Step 3 lost two minutes, this step lost none: why?
