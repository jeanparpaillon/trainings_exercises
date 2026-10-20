# Step 2 — an action, a maintenance

**Slides:** *Actions, escalations, maintenance* · **~10 min**

A problem nobody is told about waits for someone to look. An action sends
it — to the right person, for the right problems only: there is one
server and one action table for the whole room, and an action without a
filter would send everyone's problems to you.

## Where messages go here

The trainer created a media type **`Lab webhook`** and gave your user a
media of that type (*User settings → Profile → Media*). It sends nothing
anywhere: its script logs the message on the server and answers OK. What
an action sends shows as *Sent*, with its text, in the problem's
*Actions* (*Monitoring → Problems*, column *Actions*), and in
`lab0/zapi alert.get`. In production this would be your SMS, chat or
paging service's media type.

## The action

*Alerts → Actions → Trigger actions → Create action*, name `<name> pages`:

| Label | Condition |
| --- | --- |
| A | *Host group* equals `<name>` |
| B | *Host* equals `mon-<name>-control-plane` |
| C | *Host* equals `mon-<name>-worker` |
| D | *Trigger severity* is greater than or equals *Average* |
| E | *Trigger name* contains `Is not in Ready state` |

*Type of calculation*: *Custom expression*, `(A or B or C) and (D or E)`.

- B and C: the discovered node hosts are in `Applications`, not in your
  group; you only read them, and that is enough for a condition.
- E: step 1 — *node not ready* is a Warning; without E it would never be
  sent.

*Operations*: *Send message* to user `<name>`, *Send only to* `Lab
webhook`. *Recovery operations*: *Notify all involved*.

## Try it

A problem on demand: lower the threshold of step 1 on your host only.
*Data collection → Hosts*, `<name> podinfo`, *Macros*:
`{$PODINFO.ERRORS.MAX}` = `0.1`. Normal traffic is ~0.3 5xx/s.

On the dry run the problem opened **30 s** later — not 2 minutes: `min(…,2m)`
looks back at values already stored, all above 0.1 — and the message was
*Sent* a few seconds after. Then remove the host macro (the template's 1
applies again): resolved, and a *Resolved* message.

```sh
lab0/zapi alert.get "{\"output\": [\"clock\", \"subject\", \"status\"], \"time_from\": $(date -d '-15 min' +%s)}" \
  | jq -r '.[] | "\(.clock | tonumber | strftime("%T")) \(.status) \(.subject)"'    # status 1 = sent
```

## A maintenance

*Data collection → Maintenance → Create maintenance period*: `<name>
drill`, *With data collection*, active from now for 15 min, one period
*One time only*, 15 min, *Host groups* `<name>`.

Lower the threshold again, as above. Then:

- *Monitoring → Problems*: nothing — unless *Show suppressed problems* is
  ticked: the problem is there, marked suppressed (the eye icon);
- no message.

Delete the maintenance (or wait for its end). On the dry run the problem
stopped being suppressed **20 s** after the deletion, and the message was
sent **12 s** after that: the action's operations were paused, not
dropped. Remove the host macro again.

Only your own hosts can be in a maintenance: one on `mon-<name>-worker`
is refused (`No permissions to referred object`), since a maintenance
needs write on its hosts. The node's *not ready* is on `<name> mon
nodes`, which is yours — that one is covered.

## Questions

- Which of module 1's and module 2's operations — a drain, `kubeadm
  upgrade`, `upgrade-cluster.yml` — should open a maintenance first? Who
  opens it: a human in the UI, or the playbook through the API (the slide's
  `community.zabbix.zabbix_maintenance`)?
- *With data collection* or *without*: what do you lose with each, during
  an upgrade?
- The problem was there all along, only suppressed. What should the
  on-call see when the maintenance ends and the problem is still open?
