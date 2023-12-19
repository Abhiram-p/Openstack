#!/bin/bash

# Read existing network configurations for ens33 and ens34
ens33_ip=$(grep -E "^IPADDR" /etc/sysconfig/network-scripts/ifcfg-ens33 | awk -F'=' '{print $2}')
ens34_ip=$(grep -E "^IPADDR" /etc/sysconfig/network-scripts/ifcfg-ens34 | awk -F'=' '{print $2}')
netmask=$(grep -E "^NETMASK" /etc/sysconfig/network-scripts/ifcfg-ens34 | awk -F'=' '{print $2}')
gateway=$(grep -E "^GATEWAY" /etc/sysconfig/network-scripts/ifcfg-ens34 | awk -F'=' '{print $2}')
dns1=$(grep -E "^DNS1" /etc/sysconfig/network-scripts/ifcfg-ens34 | awk -F'=' '{print $2}')
dns2=$(grep -E "^DNS2" /etc/sysconfig/network-scripts/ifcfg-ens34 | awk -F'=' '{print $2}')

# Step 1: Install NTP (chrony) service
yum install chrony vim -y

# Step 2: Enable and Start the Chrony Service
systemctl enable chronyd.service
echo "server 192.168.0.120 iburst" >> /etc/chrony.conf
systemctl restart chronyd.service

# Step 3: Enable the OpenStack Repository
yum install centos-release-openstack-rocky

# Step 4: Upgrade all the packages
yum upgrade -y

# Step 5: Install the OpenStack client Packages
yum -y update
yum install python-openstackclient -y

# Step 6: Install the SELinux Package
yum install openstack-selinux -y

# Step 7: Disable SELinux
sed -i 's/enforcing/disabled/g' /etc/selinux/config
setenforce 0
sestatus

# Step 8: Stop and Disable the Firewall Service
systemctl stop firewalld.service
systemctl disable firewalld.service

# Step 9: Stop and Disable the Network Manager
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

# Step 10: Edit the hosts entry file
echo "192.168.0.120    rocky.thecloudenabled.com    rocky" >> /etc/hosts

# Step 11: Edit the Hostname of the Machine
echo "rocky" > /etc/hostname

# Step 12: Set the Hostname
hostname rocky

# Step 13: Verify the FQDN
hostname --fqdn

# Step 14: Make the DNS Entry
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Step 15: Edit the Interfaces file
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-ens33
DEVICE=ens33
ONBOOT=yes
NETBOOT=yes
IPV6INIT=no
BOOTPROTO=none
NAME=ens33
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=br-ex
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-br-ex
DEVICE=br-ex
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSIntPort
OVS_BRIDGE=br-ex
IPADDR=$ens33_ip
NETMASK=$netmask
GATEWAY=$gateway
DNS1=$dns1
DNS2=$dns2
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-ens34
TYPE="Ethernet"
BOOTPROTO="static"
DEFROUTE="yes"
PEERDNS="yes"
PEERROUTES="yes"
IPADDR="$ens34_ip"
NETMASK="$netmask"
IPV6INIT="yes"
NAME="ens34"
DEVICE="ens34"
ONBOOT="yes"
EOF

# Step 16: Tell the kernel we'll be using IPs not defined in the interfaces file
echo -e "net.ipv4.ip_forward=1\nnet.ipv4.conf.all.rp_filter=0\nnet.ipv4.conf.default.rp_filter=0" > /etc/sysctl.conf
sysctl -p

# Step 17: Install the OpenvSwitch Package, Enable and Start the OpenvSwitch Service
yum install openstack-neutron-openvswitch -y
systemctl enable openvswitch.service
systemctl start openvswitch.service

# Step 18: Create a Bridge
ovs-vsctl add-br br-ex

# Step 19: Add the Interface ens33 to Br-ex port
ovs-vsctl add-port br-ex ens33

# Step 20: Restart the System
init 6

# Step 21: Verify Internet Connectivity
ping 8.8.8.8
