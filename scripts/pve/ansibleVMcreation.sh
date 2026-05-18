#!/bin/bash
#
# Script de création des VM d'automatisation Ansible pour l'ensemble des Pods
#
# 2026-02-28 - Mitard V. : Création
# 2026-05-18 - Mitard V. : Colorisation des messages
#
scriptName=`basename $0`
scriptDir=`realpath $0`
scriptDir=`dirname $scriptDir`

AnsibleTmplID=20000

if [ $# -eq 0 ]; then
  tput setaf 1; echo -e "\n-E- Paramètre obligatoire absent !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
  exit 1
fi

while getopts "b:dDhHn:" opt; do
  case $opt in
    b)   base=$OPTARG
         ;;
    d|D) set -x
         ;;
    h|H) tput setaf 6
         echo -e "\n-I- $scriptName permet la création du modèle de VM Ansible ainsi que l'instanciation de ces machines."
         echo -e "-I- $scriptName [-d|-D] [-h|-H] -b <ID de base> -n <Nb VM>"
         echo -e "\t-d|D : Activativation des traces de débogage."
         echo -e "\t-h|H : Affichage de cette aide en ligne."
         echo -e "\t-b   : ID de base à partir duquel sont créés les VMs."
         echo -e "\t-n   : Nombre de VM Ansible à créer.\n"
         tput sgr0
         exit 0
         ;;
    n)   nbVM=$OPTARG
         ;;
    *)   tput setaf 1; echo -e "\n-E- Option $opt invalide !\n"; tput sgr0
         exit 1
         ;;
  esac
done

shift $((OPTIND-1))

if [ $# -ne 0 ]; then
  tput setaf 1; echo -e "\n-E- Nombre de paramètres incorrects !"; tput sgr0
  tput setaf 3; echo -e "-I- $scriptName -h|-H pour obtenir de l'aide en ligne.\n"; tput sgr0
fi

# Création du modèle de VM Ansible
/root/vLab/scripts/pve/ansibleSrvTmplCreation.sh -f /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img -i $AnsibleTmplID -n Ansible-Ubuntu24

# Instanciation des VM Ansible
for (( indice=1; indice<=$nbVM; indice++ )) do
  VMID=$(($base+$indice))
  tput setaf 3 echo "-I- Création de la VM $indice d'ID $VMID"; tput sgr0
  qm clone $AnsibleTmplID $VMID --full 1 --name $HOSTNAME-Ansible-Pod$indice
  qm set $VMID --ipconfig0 ip=172.16.$indice.2/16,gw=172.16.0.1 --onboot 1
done
