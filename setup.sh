#!/bin/zsh

# bootstrap cluster

gcloud beta container --project "schnauzer-163208" \
    clusters create "test-cluster" --zone "australia-southeast1-a" \
    --no-enable-basic-auth \
    --cluster-version "1.9.7-gke.11" \
    --machine-type "n1-standard-2" \
    --image-type "COS" \
    --disk-type "pd-standard" --disk-size "30" \
    --scopes "https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --num-nodes "2" \
    --no-enable-cloud-logging \
    --no-enable-cloud-monitoring \
    --enable-ip-alias \
    --network "projects/schnauzer-163208/global/networks/default" \
    --subnetwork "projects/schnauzer-163208/regions/australia-southeast1/subnetworks/default" \
    --default-max-pods-per-node "110" \
    --addons HorizontalPodAutoscaling \
    --enable-autoupgrade --enable-autorepair

# Get credentials for cluster

#gcloud auth application-default login

gcloud container clusters get-credentials test-cluster

# Give gcloud account cluster admin permissions

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)

sc install

# wait for all available

READY=0
while [ $READY -ne 4 ]
do
    sleep 5
    echo "."
    READY=$( kubectl get deployment -n service-catalog | awk '{ print $5 }' | grep -c 1 )
done

sleep 10

echo "READY\n"

sc add-gcp-broker

READY=0
while [ $READY -ne 1 ]
do
    sleep 5
    printf "."
    READY=$( kubectl get clusterservicebrokers -o 'custom-columns=BROKER:.metadata.name,STATUS:.status.conditions[0].reason' | grep -c FetchedCatalog )
done

GCP_PROJECT_ID=$(gcloud config get-value project)
GCP_PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')

gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member serviceAccount:${GCP_PROJECT_NUMBER}@cloudservices.gserviceaccount.com \
    --role=roles/owner
