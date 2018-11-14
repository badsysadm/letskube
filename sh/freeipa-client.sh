export DEBIAN_FRONTEND=noninteractive
DEBIAN_VER='stretch'
wget -qO - http://apt.numeezy.fr/numeezy.asc | apt-key add -
echo -e 'deb http://apt.numeezy.fr  '${DEBIAN_VER}' main' > /etc/apt/sources.list.d/ipa.list
apt-get update && apt-get install -y freeipa-client
mkdir -p /etc/pki/nssdb
certutil -N -d /etc/pki/nssdb
mkdir -p /var/run/ipa
ipa-client-install
echo 'session required pam_mkhomedir.so' >> /etc/pam.d/common-session
systemctl restart sssd
systemctl restart ssh
