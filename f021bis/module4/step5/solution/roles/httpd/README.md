httpd
=====

httpd on Rocky Linux 9: installed, HTTP open in firewalld, a home page from
a template, a conf.d snippet (`/etc/httpd/conf.d/m4.conf`) whose changes
restart httpd, the service started and enabled.

Role Variables
--------------

| Variable | Default | |
| --- | --- | --- |
| `web_title` | `m4` | the `<h1>` of the home page |

Example Playbook
----------------

    - name: Web server
      hosts: web
      roles:
        - httpd
