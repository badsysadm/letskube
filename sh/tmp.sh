### Installing Ansible
apt-get update && apt-get upgrade -y
apt install dirmngr
cat << EOF > /etc/apt/sources.list.d/ansible.list
deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main
EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
apt-get update && apt-get upgrade -y
apt-get install -y ansible

### Installing Docker
DOCKER_VERSION="18.06.0~ce~3-0~debian"
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
#apt-get update && apt-get install -y docker-ce=${DOCKER_VERSION}
apt-mark hold docker-ce
systemctl enable docker.service
#systemctl start docker.service

### Installing Containerd
apt-get update && apt-get upgrade -y
apt-get install -y libseccomp2 aufs-dkms
CONTAINERD_VERSION="1.1.2"
wget https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz
sha256sum cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz
curl https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz.sha256
tar --no-overwrite-dir -C / -xzf cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz
systemctl enable containerd.service
#systemctl start containerd.service
cat << EOF > /root/containerd.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF
rm -rfv cri-containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz*
### Installing Kubernetes
KUBE_VERSION="1.11.1-00"
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get upgrade -y
apt-get install -y kubelet=${KUBE_VERSION} kubeadm=${KUBE_VERSION} kubectl=${KUBE_VERSION}
apt-mark hold kubeadm kubectl kubelet
systemctl enable kubelet.service
#systemctl start kubelet.service

### Kube-cluster init
kubeadm reset -f
#sed -i '/swap/d' /etc/fstab
#swapoff -a
#kubeadm init --pod-network-cidr=192.168.0.0/16 --service-cidr=10.96.0.0/12 --apiserver-advertise-address=0.0.0.0 --apiserver-bind-port=6443 \
#--apiserver-cert-extra-sans=hostname --kubernetes-version=stable-1.11 --node-name=hostname --service-dns-domain=domain --token-ttl=0
#kubeadm init --pod-network-cidr=192.168.0.0/16

#mkdir -p $HOME/.kube
#cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#chown $(id -u):$(id -g) $HOME/.kube/config
#kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
