#!/bin/bash

# Prompt for IP addresses
read -p "Enter the Glance IP address: " GLANCE_IP
read -p "Enter the MySQL IP address: " MYSQL_IP
read -p "Enter the Memcached IP address: " MEMCACHED_IP
read -p "Enter the Keystone IP address: " KEYSTONE_IP

# Prompt for passwords
read -sp "Enter the MySQL root password: " MYSQL_ROOT_PASSWORD
echo
read -sp "Enter the Keystone admin password: " KEYSTONE_ADMIN_PASSWORD
echo
read -sp "Enter the Glance user password: " GLANCE_USER_PASSWORD
echo
read -sp "Enter the Service project password: " SERVICE_PROJECT_PASSWORD
echo

# Step 1: Create the glance user
openstack user create --domain default --password $GLANCE_USER_PASSWORD glance

# Step 2: Add the admin role to the glance user and service project
openstack role add --project service --user glance admin

# Step 3: Create the glance service entity
openstack service create --name glance --description "OpenStack Image service" image

# Steps 4-6: Create the Image service API endpoints
openstack endpoint create --region RegionOne image public http://$GLANCE_IP:9292
openstack endpoint create --region RegionOne image internal http://$GLANCE_IP:9292
openstack endpoint create --region RegionOne image admin http://$GLANCE_IP:9292

# Step 7: Install Glance packages
sudo yum install openstack-glance -y

# Step 8: Login to the database and create a database and user
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD <<MYSQL_SCRIPT
CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY '$GLANCE_USER_PASSWORD';
quit;
MYSQL_SCRIPT

# Steps 9-10: Edit Glance Configuration Files
sudo bash -c "cat > /etc/glance/glance-api.conf <<EOF
[database]
connection = mysql+pymysql://glanceUser:$GLANCE_USER_PASSWORD@$MYSQL_IP/glance

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[paste_deploy]
flavor = keystone

[keystone_authtoken]
auth_uri = http://$KEYSTONE_IP:5000
auth_url = http://$KEYSTONE_IP:5000
memcached_servers = $MEMCACHED_IP:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $GLANCE_USER_PASSWORD
EOF"

sudo bash -c "cat > /etc/glance/glance-registry.conf <<EOF
[database]
connection = mysql+pymysql://glanceUser:$GLANCE_USER_PASSWORD@$MYSQL_IP/glance

[paste_deploy]
flavor = keystone

[keystone_authtoken]
auth_uri = http://$KEYSTONE_IP:5000
auth_url = http://$KEYSTONE_IP:5000
memcached_servers = $MEMCACHED_IP:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $GLANCE_USER_PASSWORD
EOF"

# Step 11: Synchronize the glance database
sudo su -s /bin/sh -c "glance-manage db_sync" glance

# Steps 12-13: Start the glance-api and glance-registry services
sudo systemctl enable openstack-glance-api.service
sudo systemctl start openstack-glance-api.service
sudo systemctl enable openstack-glance-registry.service
sudo systemctl start openstack-glance-registry.service

# Step 14: Download cirroslinux image
sudo yum install wget -y
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img

# Step 15: Create a new image of the cirros cloud image
openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public

# Step 16: List Images
openstack image list

echo "Glance installation and configuration completed."
