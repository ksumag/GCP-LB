Role Name: vhost_deploy
=========

This role configures 2 virtual nginx-based servers on port 80 and 8080 respectivly

Requirements
------------

debian OS is requierd

Role Variables
--------------

destin_folder_site: where a sites will be laied
destin_folder_conf: where a nginx config be laied
enabled: used to do a simlinks 

Dependencies
------------

There is no dependencies at this role

Example Playbook
----------------

- hosts: servers
      roles:
         - vhost_deploy

License
-------

free

Author Information
------------------

Nahovskyi Dmytro, PhD.
E-mail: dymon.ksu@gmal.com
linkedin: https://www.linkedin.com/in/dmytro-nahovskyi-3a8658157/
Telegram: +380 97 756 50 55
