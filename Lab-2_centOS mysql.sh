#!/bin/bash

# Script to install and configure MySQL, RabbitMQ, and Memcached for OpenStack

# Prompt for MySQL password
read -sp "Enter the password for MySQL: " MYSQL_PASSWORD
echo

# Step 1: Install, Enable, and Start MariaDB Service
sudo yum install mariadb mariadb-server python2-PyMySQL -y
sudo systemctl enable mariadb.service
sudo systemctl start mariadb.service

# Step 2: Set the MySQL DB password
sudo mysql_secure_installation <<EOF

y
$MYSQL_PASSWORD
$MYSQL_PASSWORD
y
y
y
y
EOF

# Step 3: Create and edit /etc/my.cnf.d/openstack.cnf
sudo bash -c "cat > /etc/my.cnf.d/openstack.cnf <<EOF
[mysqld]
bind-address = 0.0.0.0
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF"

# Step 4: Restart MariaDB server
sudo systemctl restart mariadb.service

# Step 5: Install, Enable, and Start RabbitMQ (Message Queue)
sudo yum -y install rabbitmq-server
sudo systemctl enable rabbitmq-server.service
sudo systemctl start rabbitmq-server.service

# Step 6: Add the openstack user for RabbitMQ server
sudo rabbitmqctl add_user openstack rabbit

# Step 7: Permit configuration, write, and read access for the openstack user
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# Step 8: Install Memcached packages
sudo yum install memcached python-memcached python-openstackclient -y

# Step 9: Edit the config of memcached file
sudo bash -c 'echo "-l 0.0.0.0" >> /etc/sysconfig/memcached'

# Step 10: Enable and start the memcached service
sudo systemctl enable memcached.service
sudo systemctl start memcached.service

echo "MySQL, RabbitMQ, and Memcached installation and configuration completed."
