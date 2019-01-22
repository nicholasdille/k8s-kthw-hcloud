#!/usr/bin/env bash


cat << EOF
#####################################
# 14. Cleaning Up
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/14-cleanup.md
#####################################
EOF

echo "============== Compute Instances"

hcloud server list -o columns=id | tail -n +2 | xargs -r -n 1 hcloud server delete
