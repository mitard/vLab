#!/bin/sh
# 2026-06-07 - Mitard V. : Création pour TP IP/MPLS ESIR
#
ip link add rose type vrf table 10
ip link add orange type vrf table 20
ip link set ens21 vrf rose
ip link set ens22 vrf orange
ip link set rose up
ip link set orange up
