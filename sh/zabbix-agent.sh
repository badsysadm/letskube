wget https://repo.zabbix.com/zabbix/4.0/debian/pool/main/z/zabbix-release/zabbix-release_4.0-2+stretch_all.deb
dpkg -i zabbix-release_4.0-2+stretch_all.deb
apt-get update
apt-get install -y zabbix-agent

HOSTNAME=${1}
cat <<EOF | tee /etc/zabbix/zabbix_agentd.conf
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=zabbix.cognita.ru
ServerActive=zabbix.cognita.ru
Hostname=${HOSTNAME}
Include=/etc/zabbix/zabbix_agentd.d/*.conf
DebugLevel=3
EnableRemoteCommands=1
LogRemoteCommands=1
ListenPort=10050
ListenIP=0.0.0.0
EOF

/bin/systemctl daemon-reload
/bin/systemctl enable zabbix-agent.service
