#!/bin/bash
#
# 2026-01-12 - V. Mitard : Création
# 2026-01-30 - V. Mitard : Adaptation à une nouvelle architecture de répertoire
#
# $1 : Fichier qcow2 à personnaliser
# $2 : No PVE de modèle
# $3 : Nom du modèle

scriptName=`basename $0`
bannerFile="/etc/ssh/ssh_banner"
startupScriptURL="https://raw.githubusercontent.com/mitard/vLab/refs/heads/main/hostFiles/ansible/initialStartup.sh"
startupScript="/root/initialStartup.sh"

if [ $# -eq 0 ]; then
  echo -e "\n-E- Paramètres obligatoires absents !"
  echo -e "-I- $scriptName -h|-H pour obtenir l'aide en ligne.\n"
  exit 1
fi

while getopts "dDf:hHi:mn:" opt; do
  case $opt in
    d|D) set -x
         ;;
    f) imageFile=`basename $OPTARG`
       imageFullPath=`realpath $OPTARG`
       ;;
    h|H) echo -e "\n-I- $scriptName permet la création d'un modèle de VM Ansible, basé sur Ubuntu, pour la gestion d'un lab de routage virtuel."
         echo -e "-I- $scriptName [-d|-D] [-h|-H] -f <Chemin complet de l'image .IMG Ubuntu de base> -i <ID du modèle à créer> -n <Nom du modèle à créer>"
         echo -e "\t-d/-D: Activation du débogage."
         echo -e "\t-h/-H: Affichage de cette aide en ligne."
         exit 0
         ;;
    i) ID=$OPTARG
       ;;
    n) templateName=$OPTARG
       ;;
    *) echo "\n-E- Option $opt invalide !\n"
       ;;
  esac
done

shift $((OPTIND-1))

if [ $# -ne 0 ]; then
  echo -e "\n-E- Argument(s) $* invalide pour ce script !\n"
  exit 2
fi

res=`qm list | tr -s ' ' | cut -d' ' -f2 | grep $ID`

if [ "$res" != "" ]; then
  echo -e "\n-E- ID de machine virtuelle ou de modèle existant !\n"
  exit 4
fi

if [ ! -f $imageFullPath ]; then
  echo -e "\n-E- Fichier image IMG non trouvé !\n"
  exit 3
else
  tmpImageFile="/var/tmp/ansibleTemporaryImageFile.qcow2"
  qemu-img create -f qcow2 -o preallocation=metadata $tmpImageFile 5G
  virt-resize $imageFullPath $tmpImageFile --expand /dev/sda1
fi

guestmount -a $tmpImageFile -i --rw /mnt/iso
dd if=/dev/urandom of=/mnt/iso/var/lib/systemd/random-seed bs=512 count=4
chmod 755 /mnt/iso/var/lib/systemd/random-seed
guestunmount /mnt/iso

# Installation des paquets d'agent QEMU, Ansible et mise à jour des paquets
virt-customize -a $tmpImageFile --install qemu-guest-agent,ansible,figlet
virt-customize -a $tmpImageFile --update

# Autorisation de la connexion SSH par login/password
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config: s/PasswordAuthentication no/PasswordAuthentication yes/'
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config.d/60-cloudimg-settings.conf: s/PasswordAuthentication no/PasswordAuthentication yes/'
# Personnalisation de la bannière de connexion SSH
virt-customize -a $tmpImageFile --edit "/etc/ssh/sshd_config: s/#Banner none/Banner ${bannerFile////\\/}/"
# Copie des fichiers de configuration de l'environnement Ansible
virt-customize -a $tmpImageFile --copy-in /root/vLab/hostFiles/ansible/python3-proxmoxer_2.2.0-2_all.deb:/var
virt-customize -a $tmpImageFile --copy-in /root/vLab/hostFiles/ansible/"$HOSTNAME"Authentication.yml:/var
#virt-customize -a $tmpImageFile --copy-in /root/vLab/hostFiles/ansible/AnsibleEnv.tar.gz:/var
#virt-customize -a $tmpImageFile --copy-in /root/vLab/hostFiles/ansible/init.sh:/root
virt-customize -a $tmpImageFile --copy-in /root/vLab/hostFiles/ansible/proxmox.yml:/root
# Configuration intiale au démarrage
virt-customize -a $tmpImageFile --firstboot-command "curl --location $startupScriptURL --output $startupScript;chmod a+x $startupScript;$startupScript"

# Désactivation de l'IPv6
virt-customize -a $tmpImageFile --edit '/etc/default/grub: s/^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash/GRUB_CMDLINE_LINUX_DEFAULT="quiet ipv6.disable=1/'
virt-customize -a $tmpImageFile --edit '/etc/default/grub: s/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1/'
virt-customize -a $tmpImageFile --run-command 'update-grub'
virt-customize -a $tmpImageFile --run-command 'truncate -s 0 /etc/machine-id'

qm create $ID --name $templateName --ostype l26 --cores 1 --memory 2048 --bios ovmf --machine q35 --efidisk0 local-lvm:0,pre-enrolled-keys=0 --net0 virtio,bridge=mgmtNets --scsihw virtio-scsi-pci --agent 1 --template 1

qm set $ID --virtio0 local-lvm:0,import-from=$tmpImageFile > /dev/null

qm set $ID --ciuser ansible --cipassword ansible
qm set $ID --ipconfig0 ip=dhcp

qm set $ID --ide2 local-lvm:cloudinit
qm set $ID --boot order=virtio0

rm $tmpImageFile
