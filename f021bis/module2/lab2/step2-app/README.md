# Step 2 — an application from templates, a Secret from Vault

**Slides:** Managing manifests with Ansible · **~15 min**

nginx serving one page, in two environments, with a Secret whose value is
in Vault. Everything in `k8s/`; run from `~/m2`.

## The variables

`k8s/vars/dev.yml` and `k8s/vars/prod.yml`, three variables each:
`app_env`, `app_replicas` (dev 2, prod 3), `app_message`.

`k8s/vars/vault.yml`, encrypted (same `~/.vault_pass` as lab 1):

```sh
EDITOR=nano ansible-vault create k8s/vars/vault.yml     # vault_web_password: <something>
```

## The playbook

`k8s/app.yml`, one play on `k8s_api`, `gather_facts: false`, the
`module_defaults` of step 1, and

```yaml
  vars_files:
    - "vars/{{ app_env | default('dev') }}.yml"
    - vars/vault.yml
  vars:
    web_password: "{{ vault_web_password }}"
```

Tasks, all `kubernetes.core.k8s` — one per way of giving it an object:

| Object | How | |
| --- | --- | --- |
| Namespace `web` | inline `definition:` | |
| ConfigMap `web-page`, key `index.html` | `template:` `configmap.yaml.j2` | the page itself is [`index.html.j2`](index.html.j2) (given): `lookup('ansible.builtin.template', 'index.html.j2') \| indent(4)` |
| Secret `web-credentials`, key `password` | inline, `stringData:` | `no_log: true` — why? |
| Deployment `web` | `template:` `deployment.yaml.j2` | given: [`deployment.yaml.j2`](deployment.yaml.j2), complete the TODOs |
| Service `web`, NodePort 30081 → port `http` | `template:` `service.yaml.j2` | |

Templates go in `k8s/templates/`: the module looks for them next to the
playbook. Put `wait: true` on the Deployment.

```sh
cp ~/trainings_exercises/f021bis/module2/lab2/step2-app/*.j2 k8s/templates/
```

## Run it

```sh
ansible-playbook k8s/app.yml
curl -s 127.0.0.1:30081                       # app_message
ansible-playbook k8s/app.yml -e app_env=prod
curl -s 127.0.0.1:30081
kubectl -n web get deploy,pods
kubectl -n web get secret web-credentials -o jsonpath='{.data.password}' | base64 -d; echo
```

The `[DEPRECATION WARNING]` about the `environment` attribute comes from the
collection's own code on this ansible-core, not from your playbook.

Back to dev, and commit:

```sh
ansible-playbook k8s/app.yml
git add -A && git diff --staged --stat && git commit -m "app.yml"
```

## Questions

- What does the `checksum/page` annotation do? Remove it, change
  `app_message`, run: when does `curl` show the new message?
- Anyone with `get secret` in `web` reads the password, as you just did.
  What did Vault protect, then, and from whom?
