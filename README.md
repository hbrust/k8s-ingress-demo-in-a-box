# k8s-ingress-demo-in-a-box
This will build a demo-in-a-box for the [Citrix-Ingress-Controller (CIC)](https://github.com/citrix/citrix-k8s-ingress-controller). It is based on [Ubuntu 20.04 - Focal Fossa](https://releases.ubuntu.com/20.04/) and [Microk8s](https://microk8s.io/).

# Prerequisites
- Ubuntu 20.04 installation (2vCPU / 4GB RAM)
- optional: MicroK8s installed (the script will install it, if it is missing)
- [Citrix BLX Debian package](https://www.citrix.com/downloads/citrix-adc/)

# Architecture
This will result in an all-in-a-box system. There is then
- Kubernetes (1-node cluster, MicroK8s)
- CPX ingress on K8s (NodePort based)
- BLX used as first ingress and CPX as second ingress (2tier-ingress)
- BLX do not need second IP address and ingress is available on host port 80 and 443 
- deployed test application for HTTP ingress
- deployed K8s dashboard with HTTPs ingress

# Deployment
1. Install Ubuntu 20.04 system
2. Install `zip` or `git`
```shell
sudo apt-get install zip
```
or
```shell
sudo apt-get install git
```
3. Login to the system and clone repository
```shell
wget https://github.com/hbrust/k8s-ingress-demo-in-a-box/archive/master.zip
unzip master.zip
```
or
```shell
git clone https://github.com/hbrust/k8s-ingress-demo-in-a-box.git
```
4. change into the k8s-ingress-demo-in-a-box directory
if using `git clone` before
```shell
cd k8s-ingress-demo-in-a-box
```
or if using `wget` before
```shell
cd k8s-ingress-demo-in-a-box-master 
```
5. download the [BLX Debian package from Citrix Downloads](https://www.citrix.com/downloads/citrix-adc/)
6. Copy the `.tar.gz` package into the directory
7. execute building script with root execution rights
```shell
sudo ./build-k8s-ingress-demo-in-a-box.sh
```
8. wait about a minute for ingress to be ready

Now you can access the following services:
- `http://<hostname>:9080` -> BLX mgmt
- `https://dashboard.<hostname>` -> K8s dashboard via 2tier HTTPS ingress<br/>
   The build script displays the login token at the end of the process.
- `http://test.<hostname>` -> K8s testapp via 2tier HTTP ingress 

# Notes:
- this is for demo purpose, do not expect performance
- at this time, there is no demo beside working ingress (more to come 😊)
- at this time, there will only be host ports 80/tcp and 443/tcp working on BLX ingress (tbd: changable in future)
- BLX management is available on host port 9080 (http) and port 9443 (https)
