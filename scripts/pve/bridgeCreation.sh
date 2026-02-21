#!/bin/bash
#
# 2026-11-21 - V. Mitard : Création
#
# $1 : Fichier qcow2 à personnaliser

scriptName=`basename $0`

if [ $# -eq 0 ]; then
  echo -e "\n-E- Paramètres obligatoires absents !"
  echo -e "-I- $scriptName -h|-H pour obtenir l'aide en ligne.\n"
  exit 1
fi

while getopts "dDf:hH" opt; do
  case $opt in
    d|D) set -x
         ;;
    f) imageFile=`basename $OPTARG`
       imageFullPath=`realpath $OPTARG`
       ;;
    h|H) echo -e "\n-I- $scriptName permet la création d'une passerelle virtuel à partir d'une image QCOW2 Debian"
         echo -e "-I- $scriptName [-d|-D] [-h|-H] -f <Chemin complet de l'image QCOW2>"
         echo -e "\t-d/-D: Activation du débogage."
         echo -e "\t-h/-H: Affichage de cette aide en ligne."
         exit 0
         ;;
    *) echo -e "\n-E- Option $opt invalide !\n"
       ;;
  esac
done

shift $((OPTIND-1))

if [ $# -ne 0 ]; then
  echo -e "\n-E- Argument(s) $* invalide pour ce script !\n"
  exit 4
fi

if [ ! -f $imageFullPath ]; then
  echo -e "\n-E- Fichier image QCOW2 non trouvée !\n"
  exit 5
else
  tmpImageFile="/var/tmp/$imageFile.tmp"
  cp $imageFullPath $tmpImageFile
fi

guestmount -a $tmpImageFile -i --rw /mnt/iso
dd if=/dev/urandom of=/mnt/iso/var/lib/systemd/random-seed bs=512 count=4
chmod 755 /mnt/iso/var/lib/systemd/random-seed
guestunmount /mnt/iso

echo -e "-I- Installation et mise à jour des paquets"
virt-customize -a $tmpImageFile --install qemu-guest-agent,iptables,iptables-persistent
virt-customize -a $tmpImageFile --update

echo -e "-I- Copie de fichiers de configuration"
virt-customize -a $tmpImageFile --copy-in /var/lib/vz/template/configuration-files/rules.v4:/etc/iptables

echo -e "-I- Configuration de l'accès distant SSH"
# Autorisation de la connexion SSH par login/password
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config: s/PasswordAuthentication no/PasswordAuthentication yes/'
# Personnalisation de la bannière de connexion SSH
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config: s/#Banner none/Banner \/etc\/ssh\/ssh_banner/'

echo -e "-I- Configuration du routage IPv4"
# Activation du routage IPv4
virt-customize -a $tmpImageFile --edit '/etc/sysctl.conf: s/#net.ipv4.ip_forward/net.ipv4.ip_forward/'

echo -e "-I- Désactivation de l'IPv6"
# Désactivation de l'IPv6
virt-customize -a $tmpImageFile --edit '/etc/default/grub: s/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet ipv6.disable=1/'
virt-customize -a $tmpImageFile --run-command 'update-grub'
virt-customize -a $tmpImageFile --run-command 'truncate -s 0 /etc/machine-id'

echo -e "-I- Création et personnalisation de la machine virtuelle"
qm create $ID --name $templateName --cores 1 --memory 1024 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=mgmtNets --scsihw virtio-scsi-pci --agent 1
qm set $ID --ciuser net-admin --cipassword admin
qm set $ID --ipconfig1 ip=172.16.0.1/16
qm set $ID --ipconfig0 ip=dhcp

qm set $ID --virtio0 local-lvm:0,import-from=$tmpImageFile > /dev/null
qm set $ID --ide2 local-lvm:cloudinit
qm set $ID --boot order=virtio0

rm $tmpImageFile
