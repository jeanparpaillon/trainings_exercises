# Step 3 — alerts: symptoms and causes

**Slide:** Lab — monitoring: alerts · **~20 min**

A **PrometheusRule** in your namespace: four alerts, two kinds. Read
[`prometheusrule.yaml.tmpl`](prometheusrule.yaml.tmpl) first.

| Alert | Kind | Fires when |
| --- | --- | --- |
| `WordPressErrorRate` | symptom, `page` | more than 5 % of the blog's requests fail (Traefik) |
| `WordPressUnavailable` | symptom, `page` | no WordPress pod available |
| `MySQLDown` | cause, `ticket` | MySQL — or its exporter — does not answer |
| `MySQLLoginFailures` | cause, `ticket` | MySQL refused more than 2 logins in 5 min |

```sh
sed "s/CHANGEME/$NS/g" monitoring/step3-alerts/prometheusrule.yaml.tmpl \
  > monitoring/step3-alerts/prometheusrule.yaml
kubectl -n "$NS" apply -k monitoring/step3-alerts
kubectl -n "$NS" get prometheusrule wordpress
```

Grafana → *Alerting* → *Alert rules*: your group `wordpress-<ns>`
appears within a minute, every rule *Normal*.

## Make them fire

**Failed logins** — three wrong passwords:

```sh
for i in 1 2 3; do
  kubectl -n "$NS" exec mysql-0 -c mysql -- \
    env MYSQL_PWD=wrong mysql -uwordpress -e 'SELECT 1'
done
```

**The database goes away** — then watch the blog, and the alerts:

```sh
kubectl -n "$NS" scale sts/mysql --replicas=0
curl -s -o /dev/null -w '%{http_code}\n' http://wordpress.$NS.195.35.2.222.nip.io/   # 500
```

Each alert goes *Pending* (its `for:` is running), then *Firing*. Explore
shows the same:

```text
ALERTS{namespace="<ns>"}
```

Put MySQL back, and watch them resolve:

```sh
kubectl -n "$NS" scale sts/mysql --replicas=1
```

## Questions to answer before moving on

- Which alert fired **first** when MySQL went away, and which one would
  you want to wake somebody up?
- `MySQLDown` has `absent(mysql_up{…})`: what would `mysql_up == 0` alone
  have done when the pod was gone?
- Why does every expression name your namespace?
- The alerts fire, nobody gets a message: what decides who is told — and
  where would that live? (Alertmanager, routing per team and severity.)
