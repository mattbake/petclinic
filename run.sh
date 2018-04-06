#!/bin/bash
set -e
set -o pipefail
. /utils.sh

print_log "Completing petclinic install in GKE"

print_log "Adding Cloud SDK Repo"
cat << EOF >> /etc/yum.repos.d/google-cloud-sdk.repo
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

print_log "Installing google-cloud-sdk"
yum install -y google-cloud-sdk
print_log "Installing kubectl"
yum install -y kubectl

print_log "Saving key to JSON file (key.json)"
cat << EOF >> key.json
$GCLOUD_SERVICE_ACCOUNT_KEY_JSON
EOF

print_log `gcloud auth activate-service-account --key-file key.json`
print_log `gcloud config set project $GCLOUD_PROJECT_ID`
GCLOUD_GKE_CLUSTER_ZONE=$(gcloud container clusters list --filter="name:$KUBE_CLUSTER" | tail -1 | awk '{ print $2 }')
print_log `gcloud container clusters get-credentials $KUBE_CLUSTER --zone $GCLOUD_GKE_CLUSTER_ZONE`
print_log `kubectl run $KUBE_DEPLOYMENT_NAME --image=$KUBE_IMAGE --port 4200 run.sh $REST_API_IP $REST_API_PORT`
print_log `kubectl expose deployment $KUBE_DEPLOYMENT_NAME --type="LoadBalancer"`

print_log "Waiting for Public IP to populate"
while true;
do
    EXT_IP=$(kubectl get service $KUBE_DEPLOYMENT_NAME | tail -1 | awk '{ print $4 }')
    case "$EXT_IP" in
        "<pending>")
            ;;
        *)
            print_log "PUBLIC IP: $EXT_IP"
            break
            ;;
    esac
done
