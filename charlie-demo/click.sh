https://auth.cloud.google/signin/locations/global/workforcePools/okta-idp/providers/okta-oidc-provider?continueUrl=https://console.cloud.google/

cat okta-login.json 
gcloud auth login --login-config=okta-login.json
gcloud config list
gcloud config set project fleet-dev-1
gcloud container fleet memberships get-credentials gke-dev-us-central1-01 --location us-central1 --project fleet-dev-1
kubectl get ns 
kubectl get ns welcome
# Show contents of welcome folder
kubectl apply -f welcome-site
https://welcome.endpoints.fleet-dev-1.cloud.goog/