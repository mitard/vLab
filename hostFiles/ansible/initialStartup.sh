#!/bin/bash
bannerFile=/etc/ssh/ssh_banner
ansibleEnvURL="https://raw.githubusercontent.com/mitard/vLab/refs/heads/main/hostFiles/ansible/AnsibleEnv.tar.gz"
ansibleEnv="/var/tmp/AnsibleEnv.tar.gz"

# Installation du paquet promoxer v2 nécessaire pour le module community.proxmox
dpkg -i /var/python3-proxmoxer_2.2.0-2_all.deb
ansible-galaxy collection install git+https://github.com/ansible-collections/community.proxmox.git -p /usr/share/ansible/collections

echo "" > $bannerFile
figlet -c -f slant -k "Pod ${HOSTNAME: -1}" >> $bannerFile
echo "" >> $bannerFile
figlet -c -f term 'Serveur Ansible (Automatisation de la gestion du lab)' >> $bannerFile
echo "" >> $bannerFile
echo "export PodID=${HOSTNAME: -1}" >> ~ansible/.profile

# Installation de l'environnement Ansible pour l'utilisateur ansible
curl --location $ansibleEnvURL --output $ansibleEnv
tar -gunzip --extract --absolute-names --file $ansibleEnv
chown ansible:ansible /home/ansible/.ansible

# Initialisation du fichier d'hôte Ansible
mv ~ansible/.ansible/hostsPod ~ansible/.ansible/hosts
sed -i "s/PodID/${HOSTNAME: -1}/" ~ansible/.ansible/hosts
