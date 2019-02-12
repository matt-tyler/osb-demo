#!/bin/zsh

GCP_REGION=$(gcloud config get-value compute/region)

NAMESPACE=lightning

CMD="kubectl create namespace $NAMESPACE"

eval $CMD >/dev/null

kubectl config set-context $(kubectl config current-context) --namespace=$NAMESPACE >/dev/null

# echo 'Press any key to continue...\n'; read -k1 -s
clear

SERVICE_ACCOUNT_ID=storage-sa

echo "Create an IAM service account instance - $SERVICE_ACCOUNT_ID\n"

CMD="svcat provision gcp-iam \
  --class cloud-iam-service-account \
  --plan beta \
  --namespace $NAMESPACE \
  --param accountId=$SERVICE_ACCOUNT_ID"

echo "\n$CMD\n\n" && eval $CMD

BUCKET_ID=latency-$(uuidgen | tr A-Z a-z)

echo "\nCreate an instance of Cloud Storage - $BUCKET_ID\n"

CMD="svcat provision storage-instance --namespace $NAMESPACE \
  --class cloud-storage --plan beta \
  --param bucketId=$BUCKET_ID \
  --param location=$GCP_REGION"

echo "\n$CMD\n\n" && eval $CMD

SA_SECRET_NAME=storage-credentials
CMD="svcat bind gcp-iam --namespace $NAMESPACE --secret-name $SA_SECRET_NAME"
eval $CMD >/dev/null

### Poll for provisioning
READY=0
while [ $READY -ne 2 ]
do
    sleep 5
    printf "."
    READY=$( svcat get instance | grep -c Ready )
done

echo "\n$( svcat get instances )\n"

echo 'Press any key to continue...\n'; read -k1 -s

clear

echo "\nBind IAM service account to a secret - $SA_SECRET_NAME\n"

echo "\n$CMD\n\n"

echo "Bind permissions to IAM role\n"

CMD='svcat bind storage-instance \
  --name storage-binding \
  --namespace $NAMESPACE \
  --params-json \
"{
  \"serviceAccount\": \"$SERVICE_ACCOUNT_ID\",
  \"roles\": [
    \"roles/storage.objectCreator\",
    \"roles/storage.objectViewer\"
  ]
}"' 

echo "\n$CMD\n\n" && eval $CMD

READY=0
while [ $READY -ne 2 ]
do
    sleep 5
    printf "."
    READY=$( svcat get bindings | grep -c Ready )
done

echo "\n$( svcat get bindings )\n"

echo 'Press any key to continue...\n'; read -k1 -s

clear

echo "Deploy an application to write to the bucket\n"

CMD="cat <<EOF | kubectl apply -f - 
apiVersion: batch/v1
kind: Job
metadata:
  name: latency-job
  namespace: lightning
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      volumes:
        - name: service-account
          secret:
            secretName: storage-credentials
      containers:
      - name: storage-writer
        image: gcr.io/schnauzer-163208/osb-demo
        imagePullPolicy: Always
        volumeMounts:
          - name: service-account
            mountPath: /var/secrets/service-account
        env:
          - name: GOOGLE_APPLICATION_CREDENTIALS
            value: /var/secrets/service-account/privateKeyData
          - name: STORAGE_PROJECT
            valueFrom:
              secretKeyRef:
                name: storage-binding
                key: projectId
          - name: STORAGE_BUCKET
            valueFrom:
              secretKeyRef:
                name: storage-binding
                key: bucketId
EOF
"

echo "\n$CMD\n\n" && eval $CMD

sleep 2

echo 'Press any key to continue...\n'; read -k1 -s

clear

echo 'Get logs for the job...'

CMD="kubectl logs job/latency-job && kubectl delete job latency-job"

echo "\n$CMD\n\n" && eval $CMD
