#!/bin/bash

source config.cfg
source functions.sh

echocolor "Create database for sahara"
sleep 5

saharadb_present=$(mysql -uroot -p$MYSQL_PASS -e "
SHOW DATABASES LIKE 'sahara';
")

if [ -z "$saharadb_present" ]; then
  cat << EOF | mysql -uroot -p$MYSQL_PASS
  CREATE DATABASE sahara;
  GRANT ALL PRIVILEGES ON heat.* TO 'sahara'@'localhost' IDENTIFIED BY '$SAHARA_DBPASS';
  GRANT ALL PRIVILEGES ON heat.* TO 'sahara'@'%' IDENTIFIED BY '$SAHARA_DBPASS';
  FLUSH PRIVILEGES;
EOF
fi

echocolor "Create user sahara, service for sahara and endpoint"
sleep 7

openstack user create --domain default --password $SAHARA_PASS  sahara
openstack role add --project service --user sahara admin
openstack service create --name sahara \
  --description "OpenStack data_processing" data-processing
openstack endpoint create --region RegionOne \
  data-processing public http://$CTL_EXT_IP:8386/v1.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  data-processing internal http://$CTL_MGNT_IP:8386/v1.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  data-processing admin http://$CTL_MGNT_IP:8386/v1.1/%\(tenant_id\)s

echocolor "Install dependencies to install sahara from source code"
sleep 7

apt-get install -y python-pip python-setuptools python-virtualenv python-dev libssl-dev
#pip install pymysql virtualenv
#
#echocolor "Install sahara in virtualenv: sahara-env"
#sleep 7
#
#virtualenv sahara-env
#source sahara-env/bin/activate
#pip install http://tarballs.openstack.org/sahara/sahara-stable-newton.tar.gz
#mkdir -p sahara-env/etc/sahara/
#cp -e sahara-env/share/sahara/* sahara-env/etc/sahara/
#mv sahara-env/etc/sahara/sahara.conf.sample-basic sahara-env/etc/sahara/sahara.conf
#
#echocolor "Configure sahara"
#sahara_ctl=sahara-env/etc/sahara/sahara.conf
#test -f $sahara_ctl.orig || cp $sahara_ctl $sahara_ctl.orig
## [DEFAULT] section
ops_edit $sahara_ctl DEFAULT rpc_backend rabbit
ops_edit $sahara_ctl DEFAULT use_neutron True
ops_edit $sahara_ctl DEFAULT use_namespaces True
ops_edit $sahara_ctl DEFAULT use_floating_ips True
ops_edit $sahara_ctl DEFAULT debug False
ops_edit $sahara_ctl DEFAULT use_rootwrap True
ops_edit $sahara_ctl DEFAULT heat_enable_wait_condition False
ops_edit $sahara_ctl DEFAULT rootwrap_command 'sudo /root/sahara-env/bin/sahara-rootwrap /root/sahara-env/etc/sahara/rootwrap.conf'
ops_edit $sahara_ctl DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP
#
## [database] section
ops_edit $sahara_ctl database \
  connection mysql+pymysql://sahara:$SAHARA_DBPASS@$CTL_MGNT_IP/sahara
#
### [keystone_authtoken] section
ops_edit $sahara_ctl keystone_authtoken auth_host $CTL_MGNT_IP
ops_edit $sahara_ctl keystone_authtoken auth_type password
ops_edit $sahara_ctl keystone_authtoken auth_protocol http
ops_edit $sahara_ctl keystone_authtoken admin_user admin
ops_edit $sahara_ctl keystone_authtoken admin_password $SAHARA_PASS
ops_edit $sahara_ctl keystone_authtoken admin_tenant_name admin
#
#
#echocolor "Sync database "
#sleep 5
#sahara-env/bin/sahara-db-manage --config-file sahara-env/etc/sahara/sahara.conf upgrade head
#
#
#echocolor "Download vanilla image"
#sleep 5
#cd ..
#mkdir images
#cd images
#wget http://sahara-files.mirantis.com/images/upstream/newton/sahara-newton-vanilla-2.7.1-ubuntu.qcow2
#
#echocolor "Upload image to glance"
#sleep 5
#openstack image create --file sahara-newton-vanilla-2.7.1-ubuntu.qcow2 \
#  --disk-format qcow2 --public sahara-newton-vanilla
#
#echocolor "Register image in sahara"
#sleep 5
#SAHARA_IMAGE_ID=`glance image-list | grep sahara-newton-vanilla  | awk  '{print $2}'`
#openstack dataprocessing image register $SAHARA_IMAGE_ID --username ubuntu
#openstack  dataprocessing image tags add  $SAHARA_IMAGE_ID --tags vanilla 2.7.1
#
#echocolor "Create sahara flavor"
#sleep 5
#openstack  flavor create  sahara-flavor --ram 1024 --vcpus 1 --disk 10
#SAHARA_FLAVOR=`openstack flavor list | grep sahara-flavor | awk '{print $2}'`
#EXTERNAL_NET_ID=``
#echocolor "Create sahara template"
#sleep 7
#cd ..
#mkdir sahara-templates
#cd sahara-templates
#cat << EOF > node-group-template.json
#{
#"name": "node-group-template",
#"flavor_id": "$SAHARA_FLAVOR",
#"plugin_name": "vanilla",
#"hadoop_version": "2.7.1",
#"node_processes": ["datanode", "namenode"],
#"auto_security_group": true,
#"floating_ip_pool": "$EXTERNAL_NET_ID"
#}
#EOF
#
#openstack dataprocessing node group template create --json node-group-template.json
#NODE_GROUP_TEMPLATE_ID=`openstack dataprocessing node group template list | grep node-group-template | awk '{print $4}'`
#
#cat << EOF > cluster-template.json
#{
#"name": "cluster-template",
#"plugin_name": "vanilla",
#"hadoop_version": "2.7.1",
#"node_groups": [
#{
#"name": "master",
#"node_group_template_id": "$NODE_GROUP_TEMPLATE_ID",
#"count": 1
#}
#]
#}
#EOF
#
#openstack  dataprocessing cluster template create --json cluster-template.json
#
#
#neutron net-create net-sahara
#neutron subnet-create net-sahara --name net-sahara 10.10.0.0/24
#SAHARA_NET=`neutron net-list | grep net-sahara | awk '{print $2}'`
#CLUSTER_TEMPLATE_ID=`openstack  dataprocessing cluster template  list  | grep cluster-template | awk '{print $4}'`
#SAHARA_PRIVATE_KEY=` openstack  keypair create  sahara-key`
#echo  $"$SAHARA_PRIVATE_KEY" > private.key
#
#cat << EOF > cluster-demo.json
#{
#"name": "cluster-demo",
#"plugin_name": "vanilla",
#"hadoop_version": "1.2.1",
#"cluster_template_id" : "$CLUSTER_TEMPLATE_ID",
#"user_keypair_id": "sahara-key",
#"default_image_id": "$SAHARA_IMAGE_ID",
#"neutron_management_network": "$SAHARA_NET"
#}
#EOF
#
#openstack dataprocessing
