IP=`ip a | awk 'match($2, /192\.168\.[0-9]+\.[0-9]+/) { print substr( $2, RSTART, RLENGTH )}'`
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && apt-get install -y openjdk-8-jdk apt-transport-https
java -version
dpkg --configure -a
apt-get install -y elasticsearch kibana
echo 'network.host: '${IP} >> /etc/elasticsearch/elasticsearch.yml
echo 'http.port: 9200' >> /etc/elasticsearch/elasticsearch.yml
echo 'server.host: '${IP} >> /etc/kibana/kibana.yml
echo 'server.port: 5601' >> /etc/kibana/kibana.yml
echo 'server.name: '${HOSTNAME} >> /etc/kibana/kibana.yml
echo 'elasticsearch.url: http://'${IP}':9200' >> /etc/kibana/kibana.yml
echo 'logging.verbose: true' >> /etc/kibana/kibana.yml
/bin/systemctl daemon-reload
/bin/systemctl enable elasticsearch.service
