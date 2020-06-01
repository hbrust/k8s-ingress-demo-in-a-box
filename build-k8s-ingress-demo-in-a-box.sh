#!/bin/bash

# PREREQUISITES:
# - Ubuntu 2004
# - BLX tar.gz in directory
# - script to start with sudo

# preperations
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log="build.log"
date > $log

### BEGIN ###
echo -n "- check for privileges..."
if [ $(whoami) != "root" ]
then
  echo -e "${RED}[FAILED]${NC}"
  echo "  !!!!!! --------- NO PRIVILEGES ----------- !!!!!!"
  echo "  !!!!!!     Please execute this script      !!!!!!"
  echo "  !!!!!!      with SUDO or as ROOT user      !!!!!!"
  echo "  !!!!!! ----------------------------------- !!!!!!"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# blx version and files (todo: check existing)
echo -n "- check for BLX package..."
blxfile=$(find -name "blx*.tar.gz")
if [ -z  $blxfile ]
then
  echo -e "${RED}[FAILED]${NC}"
  echo "  !!!!!! ---- NO BLX PACKAGE AVAILABLE. ---- !!!!!!"
  echo "  !!!!!!   Please download BLX DEB-package   !!!!!!"
  echo "  !!!!!! from www.citrix.com/downloads first !!!!!!"
  echo "  !!!!!!               EXIT                  !!!!!!"
  echo "  !!!!!! ----------------------------------- !!!!!!"
  exit 1
else 
  echo -e "${GREEN}[OK]${NC}"
fi

# interface name
echo -n "- get Interface name..."
iface=$(ip route get 1.1.1.1 | awk 'BEGIN{FS=" "};{print $5}')
if [ -z $iface ]
then
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi
exit 0

# Install or check microk8s
echo -n "- install MicroK8s..."
snap install microk8s >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- enable MicroK8s DNS..."
microk8s.enable dns >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- stop MicroK8s..."
microk8s.stop >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- change MicroK8s config..."
echo -e "# enable privileged for CPX\n--allow-privileged" >> /var/snap/microk8s/current/args/kube-apiserver
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- start MicroK8s..."
microk8s.start >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# install BLX dependency
echo -n "- install BLX dependency..."
apt-get install -y ./libc6-i386_2.31-0ubuntu9_amd64.deb > $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# refresh package database
echo -n "- refresh package database..."
apt-get update > $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# unpack and install BLX
echo -n "- unpack BLX package..."
tar -xzf $blxfile >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

blxdir=$(ls -d blx* | grep -v tar.gz)

echo -n "- install BLX..."
apt-get install $blxdir/blx* -y >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi


# copy blx.conf
echo -n "- copy BLX configuration..."
cp blx.conf /etc/blx/blx.conf >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# start blx
echo -n "- enable BLX autostart..."
systemctl enable blx >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- start BLX..."
systemctl start blx >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# iptables for blx, ports 80 and 443
# todo: mor flexible port choice
echo -n "- forward host port 80 to BLX..."
iptables -t nat -A PREROUTING -p tcp -i $iface --dport 80 -j DNAT --to-destination 192.0.0.5 >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "- forward host port 443 to BLX..."
iptables -t nat -A PREROUTING -p tcp -i $iface --dport 443 -j DNAT --to-destination 192.0.0.5 >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# generate ingress files from templates
echo -n "- convert ingress template for testapp..."
convert-template.sh testapp/testapp-ingress.yaml.template > testapp/testapp-ingress.yaml
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# Begin K8s config
# deploy cpx ingress
echo "- begin K8s config..."

echo -n "-- cpx-ingress..."
microk8s.kubectl create -f cpx-ingress/cpx-ns.yaml -f cpx-ingress/cpx-rbac.yaml -f cpx-ingress/cpx.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# deploy blx ingress
echo -n "-- blx-ingress..."
microk8s.kubectl create -f blx-ingress/blx-cic-ns.yaml -f blx-ingress/cpx-mgmt-svc.yaml -f blx-ingress/blx-cic-rbac.yaml -f blx-ingress/blx-cic.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

echo -n "-- cpx-blx 2-tier-ingress..."
microk8s.kubectl create -f blx-ingress/blx-cpx-ingress.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

# deploy testapp
echo -n "-- cpx-ingress..."
microk8s.kubectl create -f testapp/namespace.yaml -f testapp/testapp.yaml -f testapp/testapp-ingress.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "{RED}[FAILED]${NC}"
  exit 1
else
  echo -e "{GREEN}[OK]${NC}"
fi

exit 0 