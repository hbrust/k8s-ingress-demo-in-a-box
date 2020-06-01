# k8s-ingress-demo-in-a-box
This will build a demo-in-a-box for the [Citrix-Ingress-Controller (CIC)](https://github.com/citrix/citrix-k8s-ingress-controller). It is based on [Ubuntu 20.04 - Focal Fossa](https://releases.ubuntu.com/20.04/) and [Microk8s](https://microk8s.io/).

# Prerequisites
- Ubuntu 20.04 installition
- optional: MicroK8s installed (the script will install it, if it is missing)
- [Citrix BLX Debian package](https://www.citrix.com/downloads/citrix-adc/)

# Architecture
This will result in a all-in-a-box system. There is then
- Kubernetes (1-node cluster, MicroK8s)
- CPX ingress on K8s (NodePort based)
- BLX used as 1-tier ingress
- BLX do not need second IP address and ingress is available on host port 80 and 443 
- deployed test application for ingress

# Notes:
- this is for demo purpose, do not expect performance
- at this time, there will only be host ports 80/tcp and 443/tcp working on BLX ingress (tbd: changable in future)
