#!/bin/bash
bannerFile=/etc/ssh/ssh_banner
ansibleEnvURL="https://raw.githubusercontent.com/mitard/vLab/refs/heads/main/hostFiles/ansible/AnsibleEnv.tar.gz"
ansibleEnv="/var/tmp/AnsibleEnv.tar.gz"

# Installation du paquet promoxer v2 nécessaire pour le module community.proxmox
#dpkg -i /var/tmp/python3-proxmoxer_2.2.0-2_all.deb
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
sed -i "s/PodID/${HOSTNAME: -1}/" ~ansible/.ansible/hostsPod
cp /var/tmp/host ~ansible/.ansible/hosts
cat ~ansible/.ansible/hostsPod >> ~ansible/.ansible/hosts
rm ~ansible/.ansible/hostsPod

cp /var/tmp/*Authentication.yml /home/ansible/
chown ansible:ansible /home/ansible/*Authentication.yml

# Récupération des scripts et playbooks Ansible
git clone https://github.com/mitard/virtualLab-playbooks.git ~ansible/playbooks
chown -R ansible:ansible ~ansible/playbooks
git clone https://github.com/mitard/virtualLab-AnsibleScripts.git ~ansible/scripts
chown -R ansible:ansible ~ansible/scripts
