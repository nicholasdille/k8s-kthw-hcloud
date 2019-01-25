#!/usr/bin/env bash


cat << EOF
#####################################
# 09. Bootstrapping the Kubernetes Worker Nodes
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
#####################################
EOF

echo "============== Prerequisites"

echo '
echo "============== Provisioning a Kubernetes Worker Node"
echo "============== Install the OS dependencies:"
{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}

echo "============== Retrieve the Pod CIDR range for the current compute instance:"
POD_CIDR=10.200.0.0/16

echo "============== Download and Install Worker Binaries"

mkdir /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "bridge": "cbr0",
    "iptables": false,
    "ip-masq": false
}
EOF
ip link add cbr0 type bridge
ip link set cbr0 up

sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
sudo apt-get update
sudo apt-get install docker-ce=18.06.*

iptables -t nat -A POSTROUTING ! -d ${POD_CIDR} -m addrtype ! --dst-type LOCAL -j MASQUERADE

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.12.0/crictl-v1.12.0-linux-amd64.tar.gz \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubelet

echo "============== Create the installation directories:"
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

echo "============== Install the worker binaries:"
{
  chmod +x kubectl kube-proxy kubelet
  sudo mv kubectl kube-proxy kubelet /usr/local/bin/
  sudo tar -xvf crictl-v1.12.0-linux-amd64.tar.gz -C /usr/local/bin/
  sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
}

echo "============== Configure CNI Networking"

echo "============== Configure the Kubelet"
{
  sudo cp ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo cp ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo cp ca.pem /var/lib/kubernetes/
}

echo "============== Create the kubelet-config.yaml configuration file:"
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

echo "============== Create the kubelet.service systemd unit file:"
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=kubenet \\
  --non-masquerade-cidr=${POD_CIDR} \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "============== Configure the Kubernetes Proxy"
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

echo "============== Create the kube-proxy-config.yaml configuration file:"
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${POD_CIDR}"
EOF

echo "============== Create the kube-proxy.service systemd unit file:"
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "============== Start the Worker Services"
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet kube-proxy
  sudo systemctl start kubelet kube-proxy
}


' > bootstrapping-k8s-worker-nodes.sh

for instance in worker-0 worker-1 worker-2; do
  echo "========= ${instance} =========="
  ssh root@${instance} -- 'bash -s' < bootstrapping-k8s-worker-nodes.sh
done

echo "============== Verification"
echo "============== The compute instances created in this tutorial will not have permission to complete this section."
echo "Run the following commands from the same machine used to create the compute instances."

echo "============== List the registered Kubernetes nodes:"
  ssh root@controller-0 \
  --command "kubectl get nodes --kubeconfig admin.kubeconfig"

echo "============== The output should be like this"
cat << EOF
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   35s   v1.12.0
worker-1   Ready    <none>   36s   v1.12.0
worker-2   Ready    <none>   36s   v1.12.0
EOF
