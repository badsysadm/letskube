CENTRAL_IP=127.0.0.1
apt-get install -y openvswitch-common openvswitch-switch
mkdir -p $GOPATH/github.com/openvswitch
cd $GOPATH/github.com/openvswitch
git clone https://github.com/openvswitch/ovn-kubernetes
cd ovn-kubernetes/go-controller
make
make install
