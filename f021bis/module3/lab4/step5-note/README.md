# Step 5 — incident note, export

**Slides:** *Incident feedback* · **~5 min**

Zabbix holds the timeline: *Monitoring → Problems*, *Show* *History*, the
last hour, your hosts — each problem's start, end, and the messages sent.
Five lines per fault, in `~/m3/incidents/`:

```sh
mkdir -p ~/m3/incidents
cat > ~/m3/incidents/$(date +%F)-control.md <<'EOF'
- detected by: …            (which problem, on which host; or nobody)
- time to detect: …         (break → first problem; → first message)
- cause: …
- fix: …
- change to the monitoring: …
EOF
```

The same for the workload fault.

## Apply the change

Each note ends with one change. Make it, now — in your template, your
hosts or your action, not in a shipped template. For example, from the
dry run:

| Seen | Change |
| --- | --- |
| podinfo's *no data* paged once, 1 s after the node came back | page only for problems that last: in the action, *Default operation step duration* `2m`, the operation's *Steps* `2`–`2`. A problem resolved within 2 minutes then sends nothing, neither *Problem* nor *Resolved* (dry run: a 1 min problem sent nothing; a 3.5 min one was sent 121 s after it opened) |
| *node not ready* is a Warning | a trigger of your own on `<name> mon nodes`, High, on the node's Ready item — or keep condition E |
| the node host's Linux template saw nothing | nothing to fix there: the API-based template did see it. Say which one you would page on |

## Export, commit

```sh
T=$(lab0/zapi template.get "{\"output\": [\"templateid\"], \"filter\": {\"host\": [\"$ZBX_USER podinfo by HTTP\"]}}" | jq -r '.[0].templateid')
lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"templates\": [\"$T\"]}}" | jq -r . > ~/m3/templates/podinfo.yaml
P=$(lab0/zapi host.get "{\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$ZBX_USER proxy\"]}}" | jq -r '.[0].hostid')
lab0/zapi configuration.export "{\"format\": \"yaml\", \"options\": {\"hosts\": [\"$P\"]}}" | jq -r . > ~/m3/hosts/$CLUSTER-proxy.yaml
lab0/render lab4/solution/dashboard.json > ~/m3/dashboard.json
A=$(lab0/zapi action.get "{\"output\": \"extend\", \"filter\": {\"name\": [\"$ZBX_USER pages\"]}, \"selectFilter\": \"extend\", \"selectOperations\": \"extend\", \"selectRecoveryOperations\": \"extend\"}")
jq . <<<"$A" > ~/m3/action.json
cd ~/m3
git add -A
git commit -m "lab4: triggers, dependency, proxy host, dashboard, action; incident notes"
git tag lab4
```

What is in Git, and what is not:

| | In `~/m3` | Comes back with |
| --- | --- | --- |
| template, triggers, macro | `templates/podinfo.yaml` | `lab0/import` |
| hosts | `hosts/` | `lab0/import` |
| podinfo's dependencies | **no**: set on the host's inherited triggers, not exported | `lab0/depend` (`make deps`) |
| dashboard | `dashboard.json`, names instead of ids | `lab0/dashboard` |
| action | `action.json`, `action.get`'s output: **ids** (group, hosts, user, media type) | by hand: not importable as it is |
| maintenance | no: an event, not configuration | |

`make catch-up-lab4` rebuilds everything above but the action.

## Questions

- Which of these would you want reviewed like code, and which may change
  in the UI at 3 am?
- The dependency and the action are not in an export. How would you keep
  them as code: the API from a script (`lab0/depend`), `community.zabbix`
  (`zabbix_action`), Terraform's Zabbix provider?
- Read one of your notes to the room. What did you change?
