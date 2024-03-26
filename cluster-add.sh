#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

while getopts p:n:l:c:t:w: flag
do
    case "${flag}" in
        p) PROJECT_ID=${OPTARG};;
        n) CLUSTER_NAME=${OPTARG};;
        l) CLUSTER_LOCATION=${OPTARG};;
        c) CONTROL_PLANE_CIDR=${OPTARG};;
        t) CLUSTER_TYPE=${OPTARG};;
        w) APP_DEPLOYMENT_WAVE=${OPTARG};;
    esac
done

echo "::Variable set::"
echo "PROJECT_ID: ${PROJECT_ID}"
echo "CLUSTER_NAME: ${CLUSTER_NAME}"
echo "CLUSTER_LOCATION: ${CLUSTER_LOCATION}"
echo "CONTROL_PLANE_CIDR:${CONTROL_PLANE_CIDR}"
echo "CONTROL_TYPE:${CLUSTER_TYPE}"
echo "APP_DEPLOYMENT_WAVE:${APP_DEPLOYMENT_WAVE}"

REGION=${CLUSTER_LOCATION:0:-2}
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
echo "REGION:${REGION}"
echo "PROJECT_NUMBER:${PROJECT_NUMBER}"
mkdir -p tmp

if [[ ${CLUSTER_TYPE} == "autopilot" ]]; then
  gcloud beta container --project ${PROJECT_ID} clusters create-auto ${CLUSTER_NAME} \
    --region ${CLUSTER_LOCATION} \
    --release-channel "rapid" \
    --network "gke-poc-toolkit" --subnetwork ${CLUSTER_LOCATION} \
    --enable-master-authorized-networks \
    --master-authorized-networks 0.0.0.0/0 \
    --security-group "gke-security-groups@nickeberts.altostrat.com" 
  # gcloud container clusters update ${CLUSTER_NAME} --project ${PROJECT_ID} \
  #   --region ${CLUSTER_LOCATION} \
  #   --enable-master-global-access 
  gcloud container clusters update ${CLUSTER_NAME} --project ${PROJECT_ID} \
    --region ${CLUSTER_LOCATION} \
    --update-labels mesh_id=proj-${PROJECT_NUMBER}
else
  gcloud beta container --project ${PROJECT_ID} clusters create ${CLUSTER_NAME} \
    --zone ${CLUSTER_LOCATION} \
    --release-channel "rapid" \
    --machine-type "e2-medium" \
    --num-nodes "3" \
    --network "gke-poc-toolkit" \
    --subnetwork ${REGION} \
    --enable-ip-alias \
    --enable-autoscaling --min-nodes "3" --max-nodes "10" \
    --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 \
    --labels mesh_id=proj-${PROJECT_NUMBER} \
    --autoscaling-profile optimize-utilization \
    --workload-pool "${PROJECT_ID}.svc.id.goog" \
    --security-group "gke-security-groups@nickeberts.altostrat.com" \
    --enable-image-streaming --node-locations ${CLUSTER_LOCATION}
    # --master-ipv4-cidr ${CONTROL_PLANE_CIDR} \
    # --enable-private-nodes \
    # --enable-master-authorized-networks \
    # --master-authorized-networks 0.0.0.0/0 \
    # --enable-master-global-access \
fi

gcloud projects add-iam-policy-binding ${PROJECT_ID} --role roles/monitoring.viewer --member "serviceAccount:${PROJECT_ID}.svc.id.goog[prod-tools/default]"

gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_LOCATION} --project ${PROJECT_ID}

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/CN=frontend.endpoints.${PROJECT_ID}.cloud.goog/O=Edge2Mesh Inc" \
-keyout tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.key \
-out tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.crt

kubectl -n asm-gateways create secret tls edge2mesh-credential \
--key=tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.key \
--cert=tmp/frontend.endpoints.${PROJECT_ID}.cloud.goog.crt --context ${CLUSTER_NAME}

git add . && git commit -m "Added ${CLUSTER_NAME} to the cluster registry folder." && git push origin main

echo "${CLUSTER_NAME} has been deployed and added to the Fleet."

gcloud beta container clusters create ${CLUSTER_NAME} --project ${CLUSTER_PROJECT} /
  --no-enable-basic-auth /
  --cluster-version "1.29.2-gke.1521000" /
  --release-channel "rapid" /
  --machine-type "e2-standard-4" /
  --image-type "COS_CONTAINERD" /
  --disk-type "pd-balanced" --disk-size "100" /
  --metadata disable-legacy-endpoints=true /
  --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" /
  --num-nodes "3" /
  --logging=SYSTEM,WORKLOAD,API_SERVER,SCHEDULER,CONTROLLER_MANAGER /
  --monitoring=SYSTEM,API_SERVER,SCHEDULER,CONTROLLER_MANAGER,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA /
  --enable-private-nodes --enable-master-global-access --enable-ip-alias /
  --network "projects/fleet-dev-1/global/networks/default" /
  --subnetwork "projects/fleet-dev-1/regions/us-east1/subnetworks/default" /
  --enable-intra-node-visibility --cluster-dns=clouddns --cluster-dns-scope=cluster /
  --default-max-pods-per-node "110" /
  --security-posture=standard --workload-vulnerability-scanning=enterprise /
  --enable-dataplane-v2 --enable-master-authorized-networks /
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS,GcePersistentDiskCsiDriver,BackupRestore,GcpFilestoreCsiDriver,GcsFuseCsiDriverConfig /
  --enable-autoupgrade --enable-autorepair /
  --max-surge-upgrade 1 --max-unavailable-upgrade 0 /
  --labels env=development,region=us-east1 /
  --binauthz-evaluation-mode=DISABLED /
  --autoscaling-profile optimize-utilization /
  --enable-managed-prometheus /
  --workload-pool "fleet-dev-1.svc.id.goog" /
  --enable-shielded-nodes /
  --security-group "gke-security-groups@gkedemos.joonix.net" /
  --enable-image-streaming