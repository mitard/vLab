#!/bin/bash
#
# Script de configuration des utilisateurs et pool de ressources Proxmox
#
# 2026-05-15 - Mitard V. : Création
#
scriptName=`basename $0`
scriptDir=`realpath $0`
scriptDir=`dirname $scriptDir`

while getopts "dDhH" opt; do
  case $opt in
    d|D) set -x
         ;;
    h|H) tput setaf 3
         echo -e "\n-I- $scriptName permet la création des utilisateurs de 9 Pods et des pools de ressources associés l'environnement de TP réseau"
         echo -e "-I- $scriptName [-d|-D] [-h|-H]"
         echo -e "\t-d|-D: Activativation des traces de débogage."
         echo -e "\t-h|-H: Affichage de cette aide en ligne.\n"
         tput sgr0
         exit 0
         ;;
    *) tput setaf 1; echo -e "\n-E- Option $opt invalide !\n"; tput sgr0
       exit 1
       ;;
  esac 
done

for (( Pod=1; Pod<=9; Pod++ )) do
  tput setaf 3; echo -e "-I- Création de l'utilisateur et des ressoureces pour le Pod #$Pod"; tput sgr0
  # Création, par Pod, d'un utilisateur et d'un pool de ressources.
  pveum pool add Pod"$Pod" --comment "Ensemble des VMs du Pod #$Pod"
  pveum user add pod"$Pod"mgmt@pve --comment "Gestion des VMs du Pod #$Pod" --password pod"$Pod"pvegui
  pveum user permissions pod"$Pod"mgmt@pve --path /pool/Pod"$Pod"
  pveum acl modify /pool/Pod"$Pod" --roles PVEVMUser --users pod"$Pod"mgmt@pve
done
