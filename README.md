# Installer un serveur zabbix

### Prérequis

Toutes les commandes suivantes requière un access administrateur

Dans un premier temps, mettre en service les dépôts epel
```
yum install epel-release
```

Mettre à jour le système
```
yum update
```

Ajouter les dépôts officiels de Zabbix
```
yum install http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
```

Installer les paquets
```
yum install zabbix-server-mysql zabbix-agent zabbix-web-mysql mysql mariadb-server httpd php php-mysql php-gd php-xml php-bcmath zabbix-get
```

### Configuration

#### La base de donnee

Initialiser la DB, activer le service de la DB au redémarrage puis la lancer
```
systemctl enable mariadb
systemctl start mariadb
```

Connexion a la DB
```
mysql -u root -p
```

Cree la table de l'utilisateur zabbix dans la base de donnee
```
mysql -u root -p -e "create database zabbix;grant all privileges on zabbix.* to zabbix@'localhost' identified by 'password';grant all privileges on zabbix.* to zabbix@'%' identified by 'password';flush privileges;"
```

Importer la structure de la base de donnee, utilisez le mot de passe nouvellement cree
```
cd /usr/share/doc/zabbix-server-mysql-*/
gunzip create.sql.gz
mysql -u root -p zabbix < create.sql
```

Modifier la configuration du serveur zabbix
```
echo 'DBHost=localhost' >> /etc/zabbix/zabbix_server.conf
echo 'DBPassword=password' >> /etc/zabbix/zabbix_server.conf
```

Modifier la configuration de l'agent zabbix
```
echo 'Server=127.0.0.1' >> /etc/zabbix/zabbix_agentd.conf
echo 'ServerActive=127.0.0.1' >> /etc/zabbix/zabbix_agentd.conf
echo 'Hostname=Zabbix Server' >> /etc/zabbix/zabbix_agentd.conf
```

Ensuite on modifie quelques valeurs dans le fichier de configuration PHP:
```
sed -i 's/^max_execution_time.*/max_execution_time=600/' /etc/php.ini
sed -i 's/^max_input_time.*/max_input_time=600/' /etc/php.ini
sed -i 's/^memory_limit.*/memory_limit=256M/' /etc/php.ini
sed -i 's/^post_max_size.*/post_max_size=32M/' /etc/php.ini
sed -i 's/^upload_max_filesize.*/upload_max_filesize=16M/' /etc/php.ini
sed -i "s/^\;date.timezone.*/date.timezone=\'Europe\/Paris\'/" /etc/php.ini
```

#### SELinux

Si SELinux est actif, il faut penser à autoriser Zabbix et Apache à communiquer ensemble :
```
setsebool -P httpd_can_connect_zabbix on
```

Mais aussi zabbix à utiliser le réseau dans le cas de vérifications externes ou de services tcp :
```
setsebool -P zabbix_can_network on
```

#### Activer et demarrer les services

On active tous les services
```
systemctl enable zabbix-agent
systemctl enable zabbix-server
systemctl enable httpd
```

Et on les demarre
```
systemctl start zabbix-agent
systemctl start zabbix-server
systemctl start httpd
```

Vous pouvez maintenan lancer le front end pour finaliser l'installation a l'addresse http://localhost/zabbix

##### /!\ si jamais le frontend zabbix vous renvois une erreur du type "The frontend does not match Zabbix database" Redemarrez simplement les services

### Cas d'erreur:

#### Politiques SELinux
Pour le service MySQL:
```
grep zabbix_agent /var/log/audit/audit.log|grep mysql.sock|tail -1| audit2allow -M zabbix_mysql
semodule -i zabbix_mysql.pp
```
Pour fping
```
grep fping /var/log/audit/audit.log | audit2allow -M zabbix_fping
semodule -i zabbix_fping.pp
```

#### MySQL Status revoie toujours down
Le service MySQL est UP mais que Zabbix renvoie toujours "Down", analyser les logs :
```
tailf /var/log/zabbix/zabbix_agentd.log
 ```
Si on a un massage genre:
```
mysqladmin: connect to server at 'localhost' failed
error: 'Can't connect to local MySQL server through socket '/var/lib/mysql/mysql.sock' (13)'
Check that mysqld is running and that the socket: '/var/lib/mysql/mysql.sock' exists!
```
Il faut cree le repertoire personnel de zabbix et lui donner les droits:
```
mkdir /var/lib/zabbix
chown -R zabbix:zabbix /var/lib/zabbix
```
Créer le fichier de préférences de mysql pour indiquer le nom du compte à utiliser par défaut :
```
vi /var/lib/zabbix/.my.cnf
```
Modifier le fichier comme suit
```
[client]
user=ro
password=ro
socket=/var/lib/mysql/mysql.sock
```
Puis donner un compte read only a la db:
```
GRANT SELECT ON *.* TO 'ro'@'localhost' IDENTIFIED BY 'ro';
FLUSH PRIVILEGES;
```
Enfin redemerer l'agent
```
systemctl restart zabbix-agent
```

#### Template ICMP ne fonctionne pas (fping)


Si le modèle ICMP Ping ne fontionne pas c'est probablement dû à des permissions incorrectes sur le programme fping.
Sauvegarder la commande fping et modifier ses permissions :
```
cp -p /usr/sbin/fping /usr/sbin/fping.old
chown root:zabbix /usr/sbin/fping
chmod 4710 /usr/sbin/fping
```

#### Créer des variables personnalisées

On peut si on le souhaite faire des variables personnalisées remontées par l'agent Zabbix.
Pour cela, on modifie le fichier de l'agent : /etc/zabbix/zabbix_agentd.conf

Voici un exemple ici avec 3 valeurs personnalisées qui remontent les températures des disques et des CPU :

```
UserParameter=hdd.tempa,sudo smartctl -a /dev/sda | grep Temperature_Celsius | awk '{ print $10 ; }'
UserParameter=cpu.tempa,sensors -u | grep -Eo 'temp2_input: ([0-9])+' | sed -e 's/temp2_input: //'
UserParameter=cpu.tempb,sensors -u | grep -Eo 'temp3_input: ([0-9])+' | sed -e 's/temp3_input: //'
```

De manière générale, la ligne doit être composée ainsi :
```
UserParameter=cle,commande
```

Une fois finis relancer l'agent
```
yum install zabbix22-agent
```

### Configuration de l'agent

On configure l'agent en indiquant l'IP du serveur Zabbix et on désactive le "Server Active"
```
sed -i 's/^Server=127.0.0.1/Server=<ADDRESS IP DU SERVEUR ZABBIX>/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/^ServerActive=127.0.0.1/ServerActive=/g' /etc/zabbix/zabbix_agentd.conf
```

### Activation des services

On active au démarrage le service de l'Agent Zabbix puis on le démarre :
```
systemctl enable zabbix-agent
systemctl start zabbix-agent
```
