gcloud container fleet clusterupgrade update \
    --default-upgrade-soaking=1d \
    --project=fleet-dev-1

gcloud container fleet clusterupgrade update \
    --upstream-fleet=fleet-dev-1 \
    --default-upgrade-soaking=1d \
    --project=fleet-prod-1