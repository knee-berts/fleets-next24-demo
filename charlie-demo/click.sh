
# Enable the GKE Enterprise api
gcloud services disable --project fleet-prod-1 anthos.googleapis.com 

# Create Prod Fleet
gcloud container fleet create --display-name production --project fleet-prod-1
gcloud container fleet update --display-name fleet-prod-1 --project fleet-prod-1

# Setup Rollout Sequencing
gcloud container fleet clusterupgrade update \
    --default-upgrade-soaking=1d \
    --project=fleet-dev-1

gcloud container fleet clusterupgrade update \
    --upstream-fleet=fleet-dev-1 \
    --default-upgrade-soaking=1d \
    --project=fleet-prod-1