yum install epel-release
yum update
yum install http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
yum install zabbix-server-mysql zabbix-agent zabbix-web-mysql mysql mariadb-server httpd php php-mysql php-gd php-xml php-bcmath zabbix-get
systemctl enable mariadb
systemctl start mariadb

mysql -u root -p -e "create database zabbix;grant all privileges on zabbix.* to zabbix@'localhost' identified by 'password';grant all privileges on zabbix.* to zabbix@'%' identified by 'password';flush privileges;"
cd /usr/share/doc/zabbix-server-mysql-*/
gunzip create.sql.gz
mysql -u root -p zabbix < create.sql

echo 'DBHost=localhost' >> /etc/zabbix/zabbix_server.conf
echo 'DBPassword=password' >> /etc/zabbix/zabbix_server.conf

echo 'Server=127.0.0.1' >> /etc/zabbix/zabbix_agentd.conf
echo 'ServerActive=127.0.0.1' >> /etc/zabbix/zabbix_agentd.conf
echo 'Hostname=Zabbix Server' >> /etc/zabbix/zabbix_agentd.conf

sed -i 's/^max_execution_time.*/max_execution_time=600/' /etc/php.ini
sed -i 's/^max_input_time.*/max_input_time=600/' /etc/php.ini
sed -i 's/^memory_limit.*/memory_limit=256M/' /etc/php.ini
sed -i 's/^post_max_size.*/post_max_size=32M/' /etc/php.ini
sed -i 's/^upload_max_filesize.*/upload_max_filesize=16M/' /etc/php.ini
sed -i "s/^\;date.timezone.*/date.timezone=\'Europe\/Paris\'/" /etc/php.ini

setsebool -P httpd_can_connect_zabbix on
setsebool -P zabbix_can_network on

systemctl enable zabbix-agent
systemctl enable zabbix-server
systemctl enable httpd
systemctl start zabbix-agent
systemctl start zabbix-server
systemctl start httpd
