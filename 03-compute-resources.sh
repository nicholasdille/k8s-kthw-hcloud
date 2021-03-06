#!/usr/bin/env bash

cat << EOF
#####################################
# 03. Provisioning Compute Resources
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md
#####################################
EOF

echo "Compute Instances"
echo "Kubernetes Controllers"
echo "Create three compute instances which will host the Kubernetes control plane:"
for i in 0 1 2; do
  hcloud server create \
    --name controller-${i} \
    --location nbg1 \
    --image ubuntu-18.04 \
    --type cx21 \
    --ssh-key 209622 \
    --ssh-key 396554
  hcloud server add-label controller-${i} name=controller-${i}
done

echo "Kubernetes Workers"
echo "Create three compute instances which will host the Kubernetes worker nodes:"
for i in 0 1 2; do
  hcloud server create \
    --name worker-${i} \
    --location nbg1 \
    --image ubuntu-18.04 \
    --type cx21 \
    --ssh-key 209622 \
    --ssh-key 396554
  hcloud server add-label worker-${i} name=worker-${i}
done

echo "Verification"
echo "List the compute instances in your default compute zone:"
hcloud server list

echo "The output should be like this."
cat << EOF
ID        NAME           STATUS    IPV4             IPV6                      DATACENTER
1699597   controller-0   running   116.203.30.211   2a01:4f8:1c1c:86b6::/64   nbg1-dc3
1699598   controller-1   running   116.203.57.39    2a01:4f8:1c1c:61c6::/64   nbg1-dc3
1699600   controller-2   running   159.69.144.21    2a01:4f8:1c1c:c4be::/64   nbg1-dc3
1699601   worker-0       running   116.203.57.40    2a01:4f8:1c1c:bd45::/64   nbg1-dc3
1699602   worker-1       running   116.203.57.38    2a01:4f8:1c1c:bd44::/64   nbg1-dc3
1699603   worker-2       running   159.69.2.76      2a01:4f8:1c1c:8c6e::/64   nbg1-dc3
EOF

echo "Configuring SSH Access"
echo "Test SSH access to the controller-0 compute instances:"
echo "If this is your first time connecting to a compute instance SSH keys will be generated for you. Enter a passphrase at the prompt to continue:"
ssh root@$(hcloud server list --selector name=controller-0 --output columns=ipv4 | tail -n +2) -- exit

echo "The output should be like this."
cat << EOF
logout
Connection to XX.XXX.XXX.XXX closed
EOF
