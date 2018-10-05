IP=`ip a | awk 'match($2, /192\.168\.[0-9]+\.[0-9]+/) { print substr( $2, RSTART, RLENGTH )}'`
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update && apt-get install -y openjdk-8-jdk apt-transport-https
java -version
dpkg --configure -a
apt-get install -y elasticsearch
echo 'network.host: '${IP} >> /etc/elasticsearch/elasticsearch.yml
/bin/systemctl daemon-reload
/bin/systemctl enable elasticsearch.service
