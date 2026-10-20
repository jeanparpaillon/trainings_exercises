# Step 5 — export, commit

**Slides:** *Lab 1 — debrief* · **~5 min**

Your Zabbix configuration is code too: at the end of each lab it goes into
`~/m3`, as the server exports it.

## Look at it

*Data collection → Hosts*, select your two hosts, *Export → YAML*: the
browser downloads it, on your laptop. Read it. The copy for Git comes from
the API, in the console:

```sh
mkdir -p ~/m3/hosts
for n in control-plane worker; do
  id=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$CLUSTER-$n\"]}}" | jq -r '.[0].hostid')
  lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"hosts\": [\"$id\"]}}" \
    | jq -r . > ~/m3/hosts/$CLUSTER-$n.yaml
done
cat ~/m3/hosts/$CLUSTER-worker.yaml
```

~20 lines per host: name, proxy, template and group **by name**, the
interface's IP. None of the 100-odd items: they come from the template,
which is linked, not copied.

## Commit

```sh
cd ~/m3
git add values.yaml hosts/
git commit -m "lab1: chart values, node hosts by hand"
git tag lab1
```

Nothing secret in either file: the PSK is in `~/.zabbix/` and in the
cluster's Secret, the password in `~/.zabbix/user.env`.

## Questions

- What in the export depends on this cluster? Would it still be right
  after `kind delete cluster` and a new `kind create`? (No: on a dry run the
  two nodes swapped IPs on re-creation. Lab 2's answer: hosts that come
  from the cluster, not from someone's hands.)
- Could you import it back as you are? Try it on one file:

  ```sh
  jq -nc --rawfile s ~/m3/hosts/$CLUSTER-worker.yaml \
    '{format: "yaml", source: $s, rules: {hosts: {updateExisting: true}}}' \
    | lab0/zapi configuration.import -
  ```

  A tenant only **reads** the shipped templates, and `configuration.import`
  refuses a host linked to a template it cannot write — `Template "Linux by
  Zabbix agent" for host "…" does not exist` — where the host form and
  `host.create` accept it. `lab0/import` shows how the catch-up gets
  around it. Who, in your organisation, would import monitoring
  configuration, with which rights?
