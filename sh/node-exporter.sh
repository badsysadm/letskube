NODE_EXPORTER_VERSION='0.18.0'
NODE_EXPORTER_FULLNAME="node_exporter-$NODE_EXPORTER_VERSION.linux-amd64"
NODE_EXPORTER_TARNAME="$NODE_EXPORTER_FULLNAME.tar.gz"
NODE_EXPORTER_TMPDIR="/tmp/$NODE_EXPORTER_FULLNAME"
NODE_EXPORTER_PREFIX="/usr/local/"

useradd --no-create-home --shell /bin/false node-exporter

mkdir -p $NODE_EXPORTER_TMPDIR
wget -qO- https://github.com/prometheus/node_exporter/releases/download/v0.18.0/node_exporter-0.18.0.linux-amd64.tar.gz | tar -zxvf - -C $NODE_EXPORTER_TMPDIR
echo "wget -qO- https://github.com/prometheus/node_exporter/releases/download/v0.18.0/node_exporter-0.18.0.linux-amd64.tar.gz | tar -zxvf - -C $NODE_EXPORTER_TMPDIR"
mv $NODE_EXPORTER_TMPDIR/$NODE_EXPORTER_FULLNAME/node_exporter $NODE_EXPORTER_PREFIX/sbin/node-exporter

cat <<EOF> /etc/systemd/system/node-exporter.service
[Unit]
Description=Node Exporter

[Service]
User=node-exporter
EnvironmentFile=/etc/default/node-exporter
ExecStart=/usr/local/sbin/node-exporter $OPTIONS

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF> /etc/default/node-exporter
OPTIONS=""
EOF

systemctl daemon-reload
systemctl start node-exporter

rm -rfv $NODE_EXPORTER_TMPDIR
systemctl status node-exporter
