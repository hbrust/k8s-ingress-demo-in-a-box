# IPtables for forwarding traffic from hostinterface to BLX
# otherwise you need promiscious mode on for VM
# first parameter is port to forward
# second  parameter is BLX address

#!/bin/bash
iface=$(ip route get 1.1.1.1 | awk 'BEGIN{FS=" "};{print $5}')
iptables -t nat -A PREROUTING -p tcp -i $iface --dport $1 -j DNAT --to-destination $2
