httpd
=====

httpd on Rocky Linux 9: installed, HTTP open in firewalld, a home page from
a template, a conf.d snippet (`/etc/httpd/conf.d/m4.conf`) whose changes
restart httpd, the service started and enabled; `/private/` behind HTTP
basic auth (`.htaccess`, `/etc/httpd/.htpasswd`).

Role Variables
--------------

| Variable | Default | |
| --- | --- | --- |
| `web_title` | `m4` | the `<h1>` of the home page |
| `web_auth_user` | `m4` | the user of `/private/` |
| `web_auth_password` | — | its password: **required**, keep it in a vault |
| `web_auth_salt` | `m4salt` | the salt of its hash: fixed, or every run changes the file |

Example Playbook
----------------

    - name: Web server
      hosts: web
      roles:
        - httpd
