#!/usr/bin/env bash

TEMPLATE_PATH=${1} 
LABEL=${2}
NAMESPACE=${3}
CI_COMMIT_REF_NAME=${4}
MIGRATE_OPTION=${5}

export LABEL=${LABEL}
export NAMESPACE=${NAMESPACE}
export CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME}

check_pod_status=$(kubectl --namespace=${NAMESPACE} get pod  $(kubectl --namespace=${NAMESPACE} get pods  -o=custom-columns=NAME:.metadata.name| grep ${NAMESPACE}) -o jsonpath="{.status.phase}")



mkdir generated
for f in $TEMPLATE_PATH/*.yaml
do
 envsubst < $f > generated/$(basename $f)
done

kubectl apply -f generated/

echo "Wait for 60 seconds until the new pod is up and running"
sleep 60

while true; do
   if [ "$check_pod_status" == "" ]
   then
        sleep 1
   	    continue
   elif [ "$check_pod_status" == "Running" ]
   then
        echo "Deployment successful"
        if [ "$MIGRATE_OPTION" == "true" ]
        then
            echo "Start migration"
            kubectl --namespace=${NAMESPACE} get pods  -o=custom-columns=NAME:.metadata.name| grep ${NAMESPACE}
            kubectl --namespace=${NAMESPACE} exec $(kubectl get pods --namespace=${NAMESPACE} -o go-template --template '{{range .items}}{{if eq (.status.phase) ("Running")}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | grep ${NAMESPACE}) -- su - deploy --c "/srv/www/mediafactory_manage/shared/scripts/unicorn restart"
            echo "migration complete"
            exit 0
        elif [ "$MIGRATE_OPTION" == "false" ]
        then    
            echo "There is no need to migrate database"
            exit 0
        else 
            echo "Wrong migrate argument!"
            exit 1
        fi
   else 
        echo "deployment get error(s)"
        exit 1
   fi
done
