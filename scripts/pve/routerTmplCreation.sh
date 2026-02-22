#!/bin/sh
#
# 2025-10-22 - V. Mitard : Création
# 2025-11-15 - V. Mitard : Ajout de l'option MPLS
# 2026-01-11 - V. Mitard : Ajout de génération d'un modèle pour la passerelle de management
# 2026-02-22 - V. Mitard : Suppression de la passerelle de management, gérée comme une VM à part entière, sans template
#
# $1 : Fichier qcow2 à personnaliser
# $2 : No PVE de modèle
# $3 : Nom du modèle

scriptName=`basename $0`
cfgFilesDir=/root/vLab/hostFiles/routers

if [ $# -eq 0 ]; then
  echo "\n-E- Paramètres obligatoires absents !"
  echo "-I- $scriptName -h|-H pour obtenir l'aide en ligne.\n"
  exit 1
fi

while getopts "dDf:hHi:mn:" opt; do
  case $opt in
    d|D) set -x
         ;;
    f) imageFile=`basename $OPTARG`
       imageFullPath=`realpath $OPTARG`
       ;;
    h|H) echo "\n-I- $scriptName permet la création d'un modèle de routeur ou passerelle virtuel à partir d'une image QCOW2 Debian"
         echo "-I- $scriptName [-d|-D] [-h|-H] -B|-R -f <Chemin complet de l'image QCOW2> -i <ID du modèle à créer> -n <Nom du modèle à créer> [-m]"
         echo "\t-B : Création de modèle de passerelle"
         echo "\t-d/-D: Activation du débogage."
         echo "\t-h/-H: Affichage de cette aide en ligne."
         echo "\t-m: Ajout des fonctionnatlités MPLS.\n"
         echo "\t-R : Création de modèle de routeur"
         exit 0
         ;;
    i) ID=$OPTARG
       ;;
    m) mpls=1
       ;;
    n) templateName=$OPTARG
       ;;
    *) echo "\n-E- Option $opt invalide !\n"
       ;;
  esac
done

shift $((OPTIND-1))

if [ $# -ne 0 ]; then
  echo "\n-E- Argument(s) $* invalide pour ce script !\n"
  exit 4
fi

if [ ! -f $imageFullPath ]; then
  echo "\n-E- Fichier image QCOW2 non trouvée !\n"
  exit 5
else
  tmpImageFile="/var/tmp/$imageFile.tmp"
  cp $imageFullPath $tmpImageFile
fi

res=`qm list | tr -s ' ' | cut -d' ' -f2 | grep $ID`

if [ "$res" != "" ]; then
  echo "\n-E- ID de machine virtuelle ou de modèle existant !\n"
  exit 4
fi

guestmount -a $tmpImageFile -i --rw /mnt/iso
dd if=/dev/urandom of=/mnt/iso/var/lib/systemd/random-seed bs=512 count=4
chmod 755 /mnt/iso/var/lib/systemd/random-seed
guestunmount /mnt/iso

echo "-I- Installation et mise à jour des paquets"
# Installation des paquets d'agent QEMU, de routeur FRR et des utilitaire d'analyse réseau mtr, tcpdump & WireShark, et mise à jour des paquets
virt-customize -a $tmpImageFile --install frr,mtr,qemu-guest-agent,tcpdump,wireshark
virt-customize -a $tmpImageFile --chmod 755:/etc/frr
virt-customize -a $tmpImageFile --chmod 644:/etc/frr/vtysh.conf
virt-customize -a $tmpImageFile --update

echo "-I- Copie de fichiers de configuration"
# Copie du fichier de création d'une VRF pour l'interface de management du routeur
virt-customize -a $tmpImageFile --copy-in $cfgFilesDir/mgmt-vrf-interfaces.yaml:/usr/local/src
virt-customize -a $tmpImageFile --copy-in $cfgFilesDir/mgmt-vrf-conf.sh:/usr/local/bin

echo "-I- Configuration de l'accès distant SSH"
# Autorisation de la connexion SSH par login/password
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config: s/PasswordAuthentication no/PasswordAuthentication yes/'
# Personnalisation de la bannière de connexion SSH
virt-customize -a $tmpImageFile --edit '/etc/ssh/sshd_config: s/#Banner none/Banner \/etc\/ssh\/ssh_banner/'

echo "-I- Configuration du routage IPv4"
# Activation du routage IPv4
virt-customize -a $tmpImageFile --edit '/etc/sysctl.conf: s/#net.ipv4.ip_forward/net.ipv4.ip_forward/'

echo "-I- Désactivation de l'IPv6"
# Désactivation de l'IPv6
virt-customize -a $tmpImageFile --edit '/etc/default/grub: s/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet ipv6.disable=1/'
virt-customize -a $tmpImageFile --run-command 'update-grub'
virt-customize -a $tmpImageFile --run-command 'truncate -s 0 /etc/machine-id'

echo "-I- Configuration des processus de routage (BGP et OSPF)"
# Activation des démons de routage BGP, OSPFv2
virt-customize -a $tmpImageFile --edit '/etc/frr/daemons: s/bgpd=no/bgpd=yes/'
virt-customize -a $tmpImageFile --edit '/etc/frr/daemons: s/ospfd=no/ospfd=yes/'

# Ajout optionnel des fonctionnalités MPLS
if [ $mpls ]; then
  echo "-I- Configuration du MPLS et du LDP"
  # Activation du démon de routage LDP, chargement des modules MPLS et définition du nombre maximum de labels supporté par le routeur
  virt-customize -a $tmpImageFile --edit '/etc/frr/daemons: s/ldpd=no/ldpd=yes/'
  virt-customize -a $tmpImageFile --run-command 'echo "\nmpls_router\nmpls_gso\nmpls_iptunnel" >> /etc/modules-load.d/modules.conf'
  virt-customize -a $tmpImageFile --run-command 'echo "\n# Definition du nombre maximum de labels MPLS\nnet.mpls.platform_labels=1048575" >> /etc/sysctl.conf'
fi

echo "-I- Création et personnalisation de la machine virtuelle"
qm create $ID --name $templateName --cores 1 --memory 1024 --net0 virtio,bridge=mgmtNets --scsihw virtio-scsi-pci --agent 1
qm set $ID --ciuser ansible --sshkeys $cfgFilesDir/ansible-key.pub
qm set $ID --ipconfig0 ip=dhcp

qm set $ID --virtio0 local-lvm:0,import-from=$tmpImageFile > /dev/null
qm set $ID --ide2 local-lvm:cloudinit
qm set $ID --boot order=virtio0

echo "-I- Création du modèle de machine virtuelle"
qm template $ID

rm $tmpImageFile
