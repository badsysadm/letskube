wget https://repo.zabbix.com/zabbix/3.0/debian/pool/main/z/zabbix-release/zabbix-release_3.0-2%2Bbuster_all.deb
dpkg -i zabbix-release_3.0-2+buster_all.deb

cat <<EOF> /etc/apt/preferences.d/zabbix-agent
Package: zabbix-*
Pin: origin repo.zabbix.com
Pin-Priority: 900
EOF

apt-get update -y && apt-get install -y zabbix-agent
rm -rfv /etc/zabbix/
mkdir /var/log/zabbix && chown zabbix:zabbix /var/log/zabbix/
mkdir /etc/zabbix/ && chown zabbix:zabbix /etc/zabbix/

cat <<EOF> /etc/zabbix/zabbix_agentd.conf
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=10
EnableRemoteCommands=0
Server=
ServerActive=
Include=/etc/zabbix/zabbix_agentd.d/
Timeout=30
EOF
echo "Hostname=$(hostname)" >> /etc/zabbix/zabbix_agentd.conf

apt-get purge -y rsyslog
apt-get install -y syslog-ng auditd

cat <<EOF> /etc/ntp.conf
interface listen 127.0.0.1
interface ignore IPv6
server 2.pool.ntp.org
server 3.pool.ntp.org
restrict default ignore
restrict 2.pool.ntp.org noquery
restrict 3.pool.ntp.org noquery
restrict 127.0.0.1
restrict -6 ::1
driftfile /var/lib/ntp/drift
keys /etc/ntp/keys
EOF

cat <<EOF>> /etc/sysctl.conf
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.lo.rp_filter = 2
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_synack_retries = 4
net.ipv4.tcp_syn_retries = 4
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control=htcp
net.nf_conntrack_max = 44097152
net.ipv4.tcp_slow_start_after_idle = 0
net.core.optmem_max = 25165824
vm.max_map_count = 262144
fs.inotify.max_user_watches=16777216
fs.inotify.max_queued_events=65536

net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

cat <<EOF>> /etc/security/limits.conf
* soft nofile 655360
* hard nofile 800000
EOF

cat <<EOF | tee /etc/ssh/sshd_config
Port 22
ListenAddress 0.0.0.0
PermitRootLogin without-password
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
EOF

mkdir -p /root/.ssh
cat <<EOF | tee /root/.ssh/authorized_keys
#admin
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDR7xwg+RXz/jhZJeXjRUbLjz8TvOI3knNYyCDxFbAEWtae1pSAiEkENhEwSs9QV6wL6qkAS6VqLLuw0azRZAmT9Q/TSQ9zjHAGOZAMDQgduW6ABijxLEsKzIT1NYNHqnyKXaad7zRu+OIWO8deVafNTN4XlvhloHVDjYlVBX/GIws1REAMOl53J/UML2XCHG8ClY0BFhTlaWnl9j6/tbOQ3E6Xd4BLazceX9YGz97nfxiHv5E+skI5sLNBOuFYjuzIhea/mHOi2+WtPwBZt3iVvsL6i3/rdowISsZA5REgi9gZbJ/NiAiKokIfY57wfP8h3/5d48sqwjglLfBWujer artemov@artemov
EOF
chmod 0400 /root/.ssh
