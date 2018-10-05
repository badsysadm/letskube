PRIMARY_HOST_IP=`ip a | awk 'match($2, /192\.168\.[0-9]+\.[0-9]+/) { print substr( $2, RSTART, RLENGTH )}'`
groupadd -f -g 1501 etcd
useradd -c "Etcd key-value store user" -d /var/lib/etcd -s /bin/false -g etcd -u 1501 etcd

curl -L --silent https://github.com/coreos/etcd/releases/download/v2.2.2/etcd-v2.2.2-linux-amd64.tar.gz -o etcd-v2.2.2-linux-amd64.tar.gz
tar --no-overwrite-dir -xzf etcd-v2.2.2-linux-amd64.tar.gz
(cd etcd-v2.2.2-linux-amd64 && mv etcd* /bin/)

rm -rf etcd-v2.3.2-linux-amd64
rm -rfv etcd-v2.2.2-linux-amd64.tar.gz

chmod 755 /bin/etcd
chmod 755 /bin/etcdctl
mkdir -p /var/lib/etcd/data
mkdir -p /var/lib/etcd/wal
chown -R etcd:etcd /var/lib/etcd
mkdir -p /etc/etcd
chown -R etcd:etcd /etc/etcd

cat > /etc/systemd/system/etcd.service << EOF
[Unit]
Description=ETCD key-value storage
Documentation=https://github.com/coreos/etcd

[Service]
User=etcd
Type=notify
EnvironmentFile=/etc/etcd/options.env
ExecStart=/bin/etcd
RestartSec=5
Restart=on-failure
LimitNOFILE=40000
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/etcd/options.env << EOF
ETCD_NAME=$(hostname -s)
ETCD_DATA_DIR=/var/lib/etcd/data
ETCD_WAL_DIR=/var/lib/etcd/wal
EOF

systemctl daemon-reload
systemctl enable etcd.service
systemctl start etcd.service
