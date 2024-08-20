export WORKDIR=`pwd`
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

gcloud services enable --project ${PROJECT_ID} \
  container.googleapis.com \
  mesh.googleapis.com \
  gkehub.googleapis.com \
  multiclusterservicediscovery.googleapis.com \
  multiclusteringress.googleapis.com \
  trafficdirector.googleapis.com \
  certificatemanager.googleapis.com


gcloud projects add-iam-policy-binding ${PROJECT_ID} --project ${PROJECT_ID} \
 --member "serviceAccount:${PROJECT_ID}.svc.id.goog[gke-mcs/gke-mcs-importer]" \
 --role "roles/compute.networkViewer"

gcloud compute addresses create mcg-ip --global --project ${PROJECT_ID}

export MCG_IP=$(gcloud compute addresses describe mcg-ip --project ${PROJECT_ID} --global --format "value(address)") 
echo ${MCG_IP}

cat <<EOF > ${WORKDIR}/dns-spec.yaml
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "frontend.endpoints.${PROJECT_ID}.cloud.goog"
x-google-endpoints:
- name: "frontend.endpoints.${PROJECT_ID}.cloud.goog"
  target: "${MCG_IP}"
EOF

gcloud endpoints services deploy ${WORKDIR}/dns-spec.yaml --project ${PROJECT_ID}

gcloud compute security-policies create edge-fw-policy --project ${PROJECT_ID} \
    --description "Block XSS attacks"

gcloud compute security-policies rules create 1000 --project ${PROJECT_ID} \
    --security-policy edge-fw-policy \
    --expression "evaluatePreconfiguredExpr('xss-stable')" \
    --action "deny-403" \
    --description "XSS attack filtering"


### Need at least one Fleet Membership to assign controller to
gcloud container fleet ingress enable --project ${PROJECT_ID}

gcloud projects add-iam-policy-binding ${PROJECT_ID} --project ${PROJECT_ID} \
    --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com" \
    --role "roles/container.admin"


### Do this right before a sync 
gcloud certificate-manager certificates create mcg-cert --project ${PROJECT_ID} \
    --domains="frontend.endpoints.${PROJECT_ID}.cloud.goog"

gcloud certificate-manager maps create mcg-cert-map --project ${PROJECT_ID}

gcloud certificate-manager maps entries create mcg-cert-map-entry --project ${PROJECT_ID} \
    --map="mcg-cert-map" \
    --certificates="mcg-cert" \
    --hostname="frontend.endpoints.${PROJECT_ID}.cloud.goog"


gcloud compute addresses create welcome-ip --global --project ${PROJECT_ID}

export WELCOME_IP=$(gcloud compute addresses describe mcg-ip --project ${PROJECT_ID} --global --format "value(address)") 
echo ${WELCOME_IP}

cat <<EOF > ${WORKDIR}/welcome-dns-spec.yaml
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "welcome.endpoints.${PROJECT_ID}.cloud.goog"
x-google-endpoints:
- name: "welcome.endpoints.${PROJECT_ID}.cloud.goog"
  target: "${WELCOME_IP}"
EOF

gcloud endpoints services deploy ${WORKDIR}/welcome-dns-spec.yaml --project ${PROJECT_ID}

gcloud projects add-iam-policy-binding projects/$PROJECT_ID \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[custom-metrics/custom-metrics-stackdriver-adapter]" \
  --role roles/monitoring.viewer 