# Step 6 — export, commit

**Slides:** *Lab 2 — debrief* · **~5 min**

What you made by hand in this lab is two hosts; everything else comes from
them. Export those two.

```sh
for h in nodes state; do
  id=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$ZBX_USER mon $h\"]}}" | jq -r '.[0].hostid')
  lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"hosts\": [\"$id\"]}}" \
    | jq -r . > ~/m3/hosts/$CLUSTER-$h.yaml
done
cat ~/m3/hosts/$CLUSTER-state.yaml
```

Read it:

- the token: `type: SECRET_TEXT`, **no value** — Zabbix never exports a
  secret macro's value. Whoever imports this sets it again;
- the filter macros, the TLS setting, the API URL: all there;
- the lifetimes you set on the discovery rules in step 4: **not there**.
  A host's changes to its templated rules are not part of the host's
  export.

Lab 1's exports describe hosts that no longer exist:

```sh
cd ~/m3
git rm -q hosts/$CLUSTER-control-plane.yaml hosts/$CLUSTER-worker.yaml
git add hosts/
git commit -m "lab2: discovery, parent hosts nodes and state"
git tag lab2
```

## Questions

- Would this export survive `kind delete cluster` and a new one? (Yes, but
  the token: a new cluster, a new ServiceAccount, a new token.) What does
  `make catch-up-lab2` do about it (`token` in the module Makefile)?
- The step 4 lifetimes are lost on re-import. Where would such a setting
  live so that it is code — on a template of your own (lab 3), linked
  instead of the shipped one?
