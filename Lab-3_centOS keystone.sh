#!/bin/bash

# Script to install and configure Keystone for OpenStack

# Prompt for Keystone IP address and other information
read -p "Enter the IP address for Keystone: " KEYSTONE_IP
read -p "Enter the MySQL IP address: " MYSQL_IP
read -p "Enter the MySQL Keystone user password: " MYSQL_KEYSTONE_PASSWORD
read -p "Enter the Memcached IP address: " MEMCACHED_IP

# Step 1: Install Memcached and Keystone packages
sudo yum install openstack-keystone httpd mod_wsgi -y

# Step 2: Create database
sudo mysql -u root -p -e "CREATE DATABASE keystone;"
sudo mysql -u root -p -e "GRANT ALL ON keystone.* TO 'keystoneUser'@'%' IDENTIFIED BY '$MYSQL_KEYSTONE_PASSWORD';"

# Step 3: Adapt the connection attribute in /etc/keystone/keystone.conf to the new database
sudo bash -c "cat > /etc/keystone/keystone.conf <<EOF
[database]
connection = mysql+pymysql://keystoneUser:$MYSQL_KEYSTONE_PASSWORD@$MYSQL_IP/keystone

[token]
provider = fernet

[cache]
memcache_servers = $MEMCACHED_IP:11211
EOF"

# Step 4: Synchronize the database
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone

# Step 5: Initialize Fernet key repositories
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

# Step 6: Bootstrap the Identity service
sudo keystone-manage bootstrap --bootstrap-password openstack \
  --bootstrap-admin-url http://$KEYSTONE_IP:5000/v3/ \
  --bootstrap-internal-url http://$KEYSTONE_IP:5000/v3/ \
  --bootstrap-public-url http://$KEYSTONE_IP:5000/v3/ \
  --bootstrap-region-id RegionOne

# Step 7: Configure httpd server
sudo bash -c "echo 'ServerName	rocky' >> /etc/httpd/conf/httpd.conf"

# Step 8: Enable and start the Httpd server
sudo ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
sudo systemctl enable httpd.service
sudo systemctl start httpd.service

# Step 9: Configure Administrative Account
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$KEYSTONE_IP:5000/v3
export OS_IDENTITY_API_VERSION=3

# Step 10: Test OpenStack users
openstack user list

# Step 11: Create the service project
openstack project create --domain default --description "Service Project" service

# Step 12: Create demo project
openstack project create --domain default --description "Demo Project" demo

# Step 13: Create demo user
openstack user create --domain default --password demo_pass demo

# Step 14: Create user role
openstack role create user

# Step 15: Add user role to demo user
openstack role add --project demo --user demo user

# Step 16: Create an admin credential file
cat <<EOF > creds
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://$KEYSTONE_IP:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

# Step 17: Create a demo credential file
cat <<EOF > democreds
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demo_pass
export OS_AUTH_URL=http://$KEYSTONE_IP:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

# Step 18: Source credentials
source creds

# Step 19: Test OpenStack users
openstack user list

echo "Keystone installation and configuration completed."
