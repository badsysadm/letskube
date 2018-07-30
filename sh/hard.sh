systemctl stop etcd
systemctl stop kubelet
systemctl stop kube-apiserver kube-controller-manager kube-scheduler

KUBE_VERSION='1.11.1'
#wget -q --show-progress --https-only --timestamping https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

#chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
#mv cfssl_linux-amd64 /usr/local/bin/cfssl
#mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
cfssl version

#wget https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl
#chmod +x kubectl
#mv kubectl /usr/local/bin/
kubectl version --client
ADM_WORKDIR=$PWD
ADM_PKIDIR=$PWD'/pki/'
ADM_TMP=${ADM_PKIDIR}'*'
mkdir -p ${ADM_PKIDIR}
rm -rfv ${ADM_TMP}

GO_VERSION='1.10.3'
ADM_OS='linux-amd64'
wget https://dl.google.com/go/go$GO_VERSION.$ADM_OS.tar.gz
tar -C /usr/local -xzf go$GO_VERSION.$ADM_OS.tar.gz
rm -rfv go1*
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go

go get -u github.com/cloudflare/cfssl/cmd/...
cp -v /$HOME/go/bin/* /bin/
cd ${ADM_PKIDIR}


### CA key
cat > ${ADM_PKIDIR}/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ${ADM_PKIDIR}/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

### Admin key
cat > ${ADM_PKIDIR}/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

### Kubelet Client key
for instance in debian slave0 slave1 slave2; do
cat > ${ADM_PKIDIR}/${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
EXTERNAL_IP=127.0.0.1
INTERNAL_IP=127.0.0.1

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} -profile=kubernetes ${instance}-csr.json | cfssljson -bare ${instance}
done

### Controller Manager key
cat > ${ADM_PKIDIR}/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

### Kube Proxy key
cat > ${ADM_PKIDIR}/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

### Scheduler client key
cat > ${ADM_PKIDIR}/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

### KubeApi key
KUBERNETES_PUBLIC_ADDRESS=127.0.0.1

cat > ${ADM_PKIDIR}/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes

### Service Account key
cat > ${ADM_PKIDIR}/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

### Distribute will be later

rm -rfv *.csr
rm -rfv *.json
ADM_CA=${ADM_PKIDIR}/pki-ca
mkdir -p ${ADM_CA}
mv ca* pki-ca/
cd ${ADM_WORKDIR}


### Slaves config generate
ADM_KUBECONFIGDIR=${ADM_WORKDIR}/config
mkdir -p ${ADM_KUBECONFIGDIR}
ADM_TMP=${ADM_KUBECONFIGDIR}'/*'
rm -rfv $ADM_TMP

for instance in debian slave0 slave1 slave2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${ADM_CA}/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${ADM_KUBECONFIGDIR}/${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${ADM_PKIDIR}/${instance}.pem \
    --client-key=${ADM_PKIDIR}/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${ADM_KUBECONFIGDIR}/${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${ADM_KUBECONFIGDIR}/${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${ADM_KUBECONFIGDIR}/${instance}.kubeconfig
done

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${ADM_CA}/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=${ADM_PKIDIR}/kube-proxy.pem \
    --client-key=${ADM_PKIDIR}/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=${ADM_KUBECONFIGDIR}/kube-proxy.kubeconfig

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${ADM_CA}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=${ADM_PKIDIR}/kube-controller-manager.pem \
    --client-key=${ADM_PKIDIR}/kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=${ADM_KUBECONFIGDIR}/kube-controller-manager.kubeconfig

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${ADM_CA}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=${ADM_PKIDIR}/kube-scheduler.pem \
    --client-key=${ADM_PKIDIR}/kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=${ADM_KUBECONFIGDIR}/kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=${ADM_KUBECONFIGDIR}/kube-scheduler.kubeconfig

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${ADM_CA}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${ADM_KUBECONFIGDIR}/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=${ADM_PKIDIR}/admin.pem \
    --client-key=${ADM_PKIDIR}/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=${ADM_KUBECONFIGDIR}/admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=${ADM_KUBECONFIGDIR}/admin.kubeconfig

  kubectl config use-context default --kubeconfig=${ADM_KUBECONFIGDIR}/admin.kubeconfig

### Encryption configs and key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > ${ADM_KUBECONFIGDIR}/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

#Copying this hueta will be later

### Etcd install
ETCD_VERSION='3.3.5'
#wget -q --show-progress --https-only --timestamping \
#  "https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-${ADM_OS}.tar.gz"

tar -xvf etcd-v${ETCD_VERSION}-${ADM_OS}.tar.gz
mv etcd-v${ETCD_VERSION}-${ADM_OS}/etcd* /usr/local/bin/
#rm -rfv etcd*

mkdir -p /etc/etcd /var/lib/etcd
cp -rfv ${ADM_CA}/ca.pem ${ADM_PKIDIR}/kubernetes-key.pem ${ADM_PKIDIR}/kubernetes.pem /etc/etcd/

ETCD_NAME='etcd'

#ETCD_NAME=$(hostname -s)
#echo "${ETCD_NAME} ${INTERNAL_IP}" >> /etc/hosts

### Add for cluster running
#  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
#  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
# --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\


cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://127.0.0.1:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
Type=notify

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem


### FINISH LINE

mkdir -p /etc/kubernetes/config

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kube-scheduler"

chmod +x kube-apiserver kube-controller-manager kube-scheduler
mv kube-apiserver kube-controller-manager kube-scheduler /usr/local/bin/

mkdir -p /var/lib/kubernetes/
cp -rfv ${ADM_CA}/ca.pem ${ADM_CA}/ca-key.pem ${ADM_PKIDIR}/kubernetes-key.pem ${ADM_PKIDIR}/kubernetes.pem \
    ${ADM_PKIDIR}/service-account-key.pem ${ADM_PKIDIR}/service-account.pem \
    ${ADM_KUBECONFIGDIR}//encryption-config.yaml /var/lib/kubernetes/

cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=false \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp -rfv ${ADM_KUBECONFIGDIR}/kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp -rfv ${ADM_KUBECONFIGDIR}/kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler


### nginx
apt-get install -y nginx

cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/

systemctl restart nginx
systemctl enable nginx

sleep 15
kubectl get componentstatuses --kubeconfig ${ADM_KUBECONFIGDIR}/admin.kubeconfig
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

cat <<EOF | kubectl apply --kubeconfig ${ADM_KUBECONFIGDIR}/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig ${ADM_KUBECONFIGDIR}/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

curl --cacert ${ADM_CA}/ca.pem https://127.0.0.1:6443/version

### Network
### OpenVSwitch
apt-get install openvswitch-common openvswitch-switch
