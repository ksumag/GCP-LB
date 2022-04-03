---
  all:
     vars:
        ansible_user: root
        ansible_ssh_private_key_file: ${access_key}
     children:
         app_servers: 
           hosts:
%{for index, k in APP_servers ~}
              ${name_app[index]}:
                ansible_host: ${ip_app[index]}      
%{endfor ~}        
              