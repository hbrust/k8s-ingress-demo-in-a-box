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
blxfile=$(find -name "blx-deb*.tar.gz")
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
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# Install or check microk8s
echo -n "- install MicroK8s..."
snap install microk8s --classic >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- enable MicroK8s DNS..."
microk8s.enable dns >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- enable MicroK8s Dashboard..."
microk8s.enable dashboard >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- stop MicroK8s..."
microk8s.stop >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- change MicroK8s config..."
echo -e "\n# enable privileged for CPX\n--allow-privileged" >> /var/snap/microk8s/current/args/kube-apiserver
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- start MicroK8s..."
microk8s.start >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# install BLX dependency
echo -n "- add architecture for BLX..."
dpkg --add-architecture i386 >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# refresh package database
echo -n "- refresh package database..."
apt-get update > $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# unpack and install BLX
echo -n "- unpack BLX package..."
tar -xzf $blxfile >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

blxdir=$(ls -d blx-deb* | grep -v tar.gz)

echo -n "- install BLX..."
apt-get install ./$blxdir/blx* -y >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi


# copy blx.conf
echo -n "- copy BLX configuration..."
cp blx.conf /etc/blx/blx.conf >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# start blx
echo -n "- enable BLX autostart..."
systemctl enable blx >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- start BLX..."
systemctl start blx >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# iptables for blx, ports 80 and 443
# todo: mor flexible port choice
echo -n "- forward host port 80 to BLX..."
iptables -t nat -A PREROUTING -p tcp -i $iface --dport 80 -j DNAT --to-destination 192.0.0.5 >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- forward host port 443 to BLX..."
iptables -t nat -A PREROUTING -p tcp -i $iface --dport 443 -j DNAT --to-destination 192.0.0.5 >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# generate ingress files from templates
echo -n "- convert blx-cpx ingress template for testapp..."
./convert-template.sh blx-ingress/blx-cpx-ingress.yaml.template > testapp/blx-cpx-ingress.yaml
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- convert dashboard ingress template for testapp..."
./convert-template.sh dashboard/dashboard-ingress.yaml.template > dashboard/dashboard-ingress.yaml
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "- convert testapp ingress template for testapp..."
./convert-template.sh testapp/testapp-ingress.yaml.template > testapp/testapp-ingress.yaml
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# Begin K8s config
echo "- begin K8s config..."

# deploy cpx ingress
# generate cert
echo -n "-- prepare cert for cpx-ingress..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout cpx-ingress/cpx.key -out cpx-ingress/cpx.pem -subj "/CN=$HOSTNAME/O=$HOSTNAME" -addext "subjectAltName = DNS:*.$HOSTNAME" >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "-- register cert for cpx-ingress..."
microk8s.kubectl create secret tls cpx-cert --key cpx-ingress/cpx.key --cert cpx-ingress/cpx.pem -n cpx-ingress >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "-- cpx-ingress..."
microk8s.kubectl create -f cpx-ingress/cpx-ns.yaml -f cpx-ingress/cpx-rbac.yaml -f cpx-ingress/cpx.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# deploy blx ingress
echo -n "-- blx-ingress..."
microk8s.kubectl create -f blx-ingress/blx-cic-ns.yaml -f blx-ingress/blx-mgmt-svc.yaml -f blx-ingress/blx-cic-rbac.yaml -f blx-ingress/blx-cic.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "-- cpx-blx 2-tier-ingress..."
microk8s.kubectl create -f blx-ingress/blx-cpx-ingress.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# deploy dashboard ingress
echo -n "-- prepare cert for dashboard-ingress..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout dashboard/wildcard.key -out dashboard/wildcard.pem -subj "/CN=$HOSTNAME/O=$HOSTNAME" -addext "subjectAltName = DNS:*.$HOSTNAME" >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "-- register cert for dashboard-ingress..."
microk8s.kubectl create secret tls wildcard-cert --key dashboard-ingress/wildcard.key --cert dashboard-ingress/wildcard.pem -n kube-system >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -n "-- dashboard-ingress..."
microk8s.kubectl create -f dashboard/dashboard-ingress.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

# deploy testapp
echo -n "-- testapp..."
microk8s.kubectl create -f testapp/testapp-ns.yaml -f testapp/testapp.yaml -f testapp/testapp-ingress.yaml >> $log
if [ $? != 0 ]
then 
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo -e "- end k8s config ${GREEN}[DONE]${NC}"
# end K8s config

# get dashboard token
echo -n "- get auth token for dashboard..."
token=$(microk8s kubectl -n kube-system describe secret \
      $(microk8s kubectl -n kube-system get secret | \
      grep default-token | cut -d " " -f1) | \
      grep "token:" | cut -d " " -f7)
if [ $? != 0 ]
then
  echo -e "${RED}[FAILED]${NC}"
  exit 1
else
  echo -e "${GREEN}[OK]${NC}"
fi

echo ""
echo "------- YOUR DASHBOARD TOKEN"
echo $token
echo "-------"
echo ""

# final output
echo "  ****** ------- FINISH DEPLOYMENT"
echo "  ******  You can reach the services:"
echo "  ******    - BLX Mgmt: http://$HOSTNAME:9080!"
echo "  ******    - K8s dashboard: https://dashboard.$HOSTNAME"
echo "  ******    - testapp: http://test.$HOSTNAME "
echo "  ****** -------"

exit 0 
