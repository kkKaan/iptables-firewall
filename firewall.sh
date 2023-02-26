#!/bin/bash

# adding network namespaces
sudo ip netns add client1 
sudo ip netns add client2
sudo ip netns add server
sudo ip netns add firewall

# creating virtual ethernet connections between some interface that will be assigned later
sudo ip link add iff1 type veth peer name ifc1
sudo ip link add iff2 type veth peer name ifc2
sudo ip link add iff3 type veth peer name ifs
sudo ip link add iffh type veth peer name ifh

# assigning interfaces to namespaces
sudo ip link set dev iff1 netns firewall
sudo ip link set dev iff2 netns firewall
sudo ip link set dev iff3 netns firewall
sudo ip link set dev iffh netns firewall
sudo ip link set dev ifc1 netns client1
sudo ip link set dev ifc2 netns client2
sudo ip link set dev ifs netns server

# setting all interfaces up
sudo ip netns exec firewall ip link set dev iff1 up
sudo ip netns exec firewall ip link set dev iff2 up
sudo ip netns exec firewall ip link set dev iff3 up
sudo ip netns exec firewall ip link set dev iffh up
sudo ip netns exec firewall ip link set dev lo up
sudo ip netns exec client1 ip link set dev ifc1 up
sudo ip netns exec client1 ip link set dev lo up
sudo ip netns exec client2 ip link set dev ifc2 up
sudo ip netns exec client2 ip link set dev lo up
sudo ip netns exec server ip link set dev ifs up
sudo ip netns exec server ip link set dev lo up

# assigning ip addresses according to their subnets to interfaces
sudo ip netns exec firewall ip addr add 192.0.2.2/26 dev iff1
sudo ip netns exec firewall ip addr add 192.0.2.66/26 dev iff2
sudo ip netns exec firewall ip addr add 192.0.2.130/26 dev iff3
sudo ip netns exec firewall ip addr add 192.0.2.194/26 dev iffh
sudo ip netns exec client1 ip addr add 192.0.2.1/26 dev ifc1
sudo ip netns exec client2 ip addr add 192.0.2.65/26 dev ifc2
sudo ip netns exec server ip addr add 192.0.2.129/26 dev ifs

# creating an interface for host machine and giving an ip to it
sudo ip link set dev ifh up
sudo ip addr add 192.0.2.193/26 dev ifh

# enabling forwarding in host machine and firewall
sudo ip netns exec firewall sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.ip_forward=1

# adding default routes and connections
sudo ip netns exec client1 ip route add default via 192.0.2.2
sudo ip netns exec client2 ip route add default via 192.0.2.66
sudo ip netns exec server ip route add default via 192.0.2.130

sudo route add -net 192.0.2.0 netmask 255.255.255.0 gw 192.0.2.194
sudo iptables -t nat -A POSTROUTING -s 192.0.2.0/24  -j MASQUERADE
sudo ip netns exec firewall ip route add default via 192.0.2.193 dev iffh

#-------------------------------------------------------------------------- IPTABLES --------------------------------------------------------------------------

sudo iptables --policy FORWARD ACCEPT # docker automatically drops that if installed

# the default settings are accept all of that, first you need to drop everything to specify it.
sudo ip netns exec firewall iptables --policy INPUT DROP
sudo ip netns exec firewall iptables --policy OUTPUT DROP
sudo ip netns exec firewall iptables --policy FORWARD DROP

# the rest of the code adds the necessary rules to the firewall 
sudo ip netns exec firewall iptables -A OUTPUT -p icmp -j ACCEPT
sudo ip netns exec firewall iptables -A OUTPUT -p tcp -j ACCEPT

sudo ip netns exec firewall iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo ip netns exec firewall iptables -I INPUT -p icmp -s 192.0.2.64/26 -d 192.0.2.64/26 -j ACCEPT

sudo ip netns exec firewall iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p icmp -s 192.0.2.0/26 -d 192.0.2.128/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p icmp -s 192.0.2.0/26 -d 192.0.2.192/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p icmp -s 192.0.2.64/26 -d 192.0.2.192/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p icmp -s 192.0.2.128/26 -d 192.0.2.192/26 -j ACCEPT

sudo ip netns exec firewall iptables -I FORWARD -p tcp --dport 80 -s 192.0.2.64/26 -d 192.0.2.128/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p tcp --dport 80 -s 192.0.2.0/26 -d 192.0.2.192/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p tcp --dport 80 -s 192.0.2.64/26 -d 192.0.2.192/26 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p tcp --dport 80 -s 192.0.2.128/26 -d 192.0.2.192/26 -j ACCEPT

sudo ip netns exec firewall iptables -I FORWARD -p icmp ! -d 192.0.0.0/8 -j ACCEPT
sudo ip netns exec firewall iptables -I FORWARD -p tcp ! -d 192.0.0.0/8  --dport 80 -j ACCEPT


