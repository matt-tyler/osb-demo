#!/bin/zsh

GCP_PROJECT_ID=$(gcloud config get-value project)
GCP_PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')

gcloud projects remove-iam-policy-binding ${GCP_PROJECT_ID} \
    --member serviceAccount:${GCP_PROJECT_NUMBER}@cloudservices.gserviceaccount.com \
    --role=roles/owner

sc remove-gcp-broker

sc uninstall

gcloud container clusters delete test-cluster --async --quiet
