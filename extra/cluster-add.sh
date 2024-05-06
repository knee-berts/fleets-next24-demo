#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

while getopts p:n:l:e: flag
do
    case "${flag}" in
        p) PROJECT_ID=${OPTARG};;
        n) CLUSTER_NAME=${OPTARG};;
        l) CLUSTER_LOCATION=${OPTARG};;
        e) ENV=${OPTARG};;
    esac
done

echo "::Variable set::"
echo "PROJECT_ID: ${PROJECT_ID}"
echo "CLUSTER_NAME: ${CLUSTER_NAME}"
echo "CLUSTER_LOCATION: ${CLUSTER_LOCATION}"

PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
echo "PROJECT_NUMBER:${PROJECT_NUMBER}"
mkdir -p tmp

gcloud beta container clusters create ${CLUSTER_NAME} --project ${PROJECT_ID} \
  --location ${CLUSTER_LOCATION} \
  --no-enable-basic-auth \
  --gateway-api=standard \
  --release-channel "regular" \
  --machine-type "e2-standard-4" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-balanced" --disk-size "100" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
  --num-nodes "3" \
  --logging=SYSTEM,WORKLOAD,API_SERVER,SCHEDULER,CONTROLLER_MANAGER \
  --monitoring=SYSTEM,API_SERVER,SCHEDULER,CONTROLLER_MANAGER,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA \
  --enable-private-nodes --enable-master-global-access --enable-ip-alias \
  --enable-intra-node-visibility --cluster-dns=clouddns --cluster-dns-scope=cluster \
  --default-max-pods-per-node "110" \
  --security-posture=standard --workload-vulnerability-scanning=enterprise \
  --enable-dataplane-v2 --enable-master-authorized-networks \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS,GcePersistentDiskCsiDriver,BackupRestore,GcpFilestoreCsiDriver,GcsFuseCsiDriver \
  --enable-autoupgrade --enable-autorepair \
  --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
  --labels env=${ENV},region=${CLUSTER_LOCATION} \
  --binauthz-evaluation-mode=DISABLED \
  --autoscaling-profile optimize-utilization \
  --enable-managed-prometheus \
  --workload-pool "$PROJECT_ID.svc.id.goog" \
  --enable-shielded-nodes \
  --security-group "gke-security-groups@gkedemos.joonix.net" \
  --enable-image-streaming

# gcloud projects add-iam-policy-binding ${PROJECT_ID} --role roles/monitoring.viewer --member "serviceAccount:${PROJECT_ID}.svc.id.goog[prod-tools/default]"

gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_LOCATION} --project ${PROJECT_ID}

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/CN=frontend.endpoints.${PROJECT_ID}.cloud.goog/O=Edge2Mesh Inc" \
-keyout tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.key \
-out tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.crt

kubectl -n asm-gateways create secret tls edge2mesh-credential \
--key=tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.key \
--cert=tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.crt --context ${CLUSTER_NAME}

echo "${CLUSTER_NAME} has been deployed and added to the Fleet."

