#!/bin/sh
#
# Script de configuration initiale d'un hyperviseur Proxmox
#
# 2026-02-21 - Mitard V. : Création
#
authenticationFileName="$HOSTNAME"Authentication.yml
authenticationFileDir=~/vLab/hostFiles/ansible

# Installation de paquets complémentaires
apt-get install -y figlet libguestfs-tools

# Personnalisation de la bannière de connexion
figlet -f banner -c $HOSTNAME > /etc/ssh/ssh_banner
sed -i "s/#Banner none/Banner \/etc\/ssh\/ssh_banner/" /etc/ssh/sshd_config

# Personnalisation du Shell
sed -i "s/# export/export/" /root/.bashrc
sed -i "s/# eval/eval/" /root/.bashrc
sed -i "s/# alias l/alias l/g" /root/.bashrc
sed -i "s/-l\'/-alF\'/" /root/.bashrc

# Création du répertoire /mnt/iso pour le montage d'images ISO
mkdir -p /mnt/iso

# Téléchargement des images pour la création des machines virtuelles
wget -P /var/lib/vz/template/iso https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
wget -P /var/lib/vz/template/iso https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Création d'un utilisateur 'ansible'
pveum role add AnsibleMgmt --privs "Datastore.Allocate,Datastore.AllocateSpace,Datastore.Audit,Sys.Audit,Sys.Modify,Sys.PowerMgmt,VM.Allocate,VM.Audit,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Monitor,VM.PowerMgmt,SDN.Use"
pveum user add ansible@pve --comment "Utilisateur Ansible pour automatisation des tâches"
pveum user token add ansible@pve ansibleAPItoken --comment "Jeton d'acces pour automatisation Ansible" --privsep 0 > /var/tmp/tokenData
pveum aclmod / -user ansible@pve -role AnsibleMgmt

# Création du fichier YAML d'authentification Ansible
userName=`grep tokenid /var/tmp/tokeData | cut -d'!' -f1 | cut -d' ' -f4`
tokenName=`grep tokenid /var/tmp/tokeData | cut -d'!' -f2 | cut -d' ' -f1`
token=`grep value /var/tmp/tokeData | grep -v key | cut -d' ' -f11`
echo "pve_api_host: $HOSTNAME" > $authentifcationFileDir/$authenticationFileName
echo "pve_api_user: $userName" >> $authentifcationFileDir/$authenticationFileName
echo "pve_api_token_id: $tokenName" >> $authentifcationFileDir/$authenticationFileName
echo "pve_api_token_secret: $token" >> $authentifcationFileDir/$authenticationFileName

# Installation du package python3-proxmoxer depuis la version Trixie (Debian 13)
curl -LO http://ftp.de.debian.org/debian/pool/main/p/proxmoxer/python3-proxmoxer_2.2.0-1_all.deb
dpkg -i python3-proxmoxer_2.2.0-1_all.deb
rm python3-proxmoxer_2.2.0-1_all.deb
