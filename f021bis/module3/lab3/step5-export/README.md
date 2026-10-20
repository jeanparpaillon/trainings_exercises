# Step 5 — export, commit

**Slides:** *Lab 3 — debrief* · **~5 min**

The template is the deliverable; the host is one line that links it.

```sh
T=$(lab0/zapi template.get "{\"output\": [\"templateid\"], \"filter\": {\"host\": [\"$ZBX_USER podinfo by HTTP\"]}}" | jq -r '.[0].templateid')
H=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$ZBX_USER podinfo\"]}}" | jq -r '.[0].hostid')
mkdir -p ~/m3/templates
lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"templates\": [\"$T\"]}}" \
  | jq -r . > ~/m3/templates/podinfo.yaml
lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"hosts\": [\"$H\"]}}" \
  | jq -r . > ~/m3/hosts/$CLUSTER-podinfo.yaml
cat ~/m3/hosts/$CLUSTER-podinfo.yaml
```

Read the template's export:

- items, discovery rules, prototypes, the calculated items' formulas, the
  macros with their defaults: all there, in ~250 lines;
- a `uuid` on the template and on each item, rule and prototype. It is
  how an import recognises an object it already has, **server-wide**, and
  the import refuses a template without one (`the tag "uuid" is
  missing`). Two trainees importing
  the same file would be importing the same template: in
  `lab3/solution/` they are `${UUID:…}`, which `lab0/render` turns into
  uuids of your own;
- the host's export: a name, a proxy, a group, `templates: - name: <name>
  podinfo by HTTP`. No items: they are the template's.

```sh
cd ~/m3
git add templates/ hosts/
git commit -m "lab3: podinfo by HTTP, template and host"
git tag lab3
```

## Questions

- Who owns `templates/podinfo.yaml` in your organisation: the application
  team, who knows what its metrics mean and when they change, or the
  monitoring team, who knows Zabbix? Who reviews a change of threshold
  (lab 4)?
- How does it reach the server: by hand (*Import* in the UI), the API
  (`configuration.import`, as `make catch-up-lab3` does through
  `lab0/import`), or Ansible's `community.zabbix` collection, with the
  application's own deployment (module 2)?
- The template has `{$PODINFO.URL}`; the host does not set it. In which
  file would a second cluster's podinfo set it?
