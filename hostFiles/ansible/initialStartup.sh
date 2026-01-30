#!/bin/bash
bannerFile=/etc/ssh/ssh_banner

dpkg -i /var/python3-proxmoxer_2.2.0-2_all.deb
ansible-galaxy collection install git+https://github.com/ansible-collections/community.proxmox.git -p /usr/share/ansible/collections
tar -gunzip --extract --absolute-names --file /var/AnsibleEnv.tar.gz
echo "" > $bannerFile
figlet -c -f slant -k "Pod ${HOSTNAME: -1}" >> $bannerFile
echo "" >> $bannerFile
figlet -c -f term 'Serveur Ansible (Automatisation de la gestion du lab)' >> $bannerFile
echo "" >> $bannerFile
echo "PodID=${HOSTNAME: -1}" >> ~ansible/.profile

chown ansible:ansible /home/ansible/.ansible

# Initialisation du fichier d'hôte Ansible
mv ~ansible/.ansible/hostsPod ~ansible/.ansible/hosts
sed -i "s/PodID/${HOSTNAME: -1}/" ~ansible/.ansible/hosts
