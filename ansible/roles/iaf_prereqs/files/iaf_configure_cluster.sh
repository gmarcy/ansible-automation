#!/bin/bash -e

BASE_DIR="$(cd $(dirname $0) && pwd)"

# oc logged in
if ! oc whoami; then
  echo "Not logged in. Please login to your OpenShift cluster as a cluster-admin."
  exit 1
fi

# trap "rm -f /tmp/pull-secret-*.json /tmp/registry-*.json" EXIT

if [ -z "$CP_STG_USERNAME" ] && [ -z "$CP_STG_PASSWORD" ]; then
    echo "CP_STG_USERNAME and CP_STG_PASSWORD must be set."
    echo ""
    echo "You can get read-only API key from https://wwwpoc.ibm.com/myibm/products-services/containerlibrary. If so, use 'cp' as the value for CP_STG_USERNAME environment variable."
    exit 1
fi

if [ -z "$CP_USERNAME" ] && [ -z "$CP_PASSWORD" ]; then
    echo "CP_USERNAME and CP_PASSWORD must be set"
    echo ""
    echo "You can get read-only API key from https://myibm.ibm.com/products-services/containerlibrary. If so, use 'cp' as the value for CP_USERNAME environment variable."
    exit 1
fi

if [ -z "$DOCKER_USERNAME" ] && [ -z "$DOCKER_PASSWORD" ]; then
    echo "DOCKER_USERNAME and DOCKER_PASSWORD must be set"
    exit 1
fi

if [ -z "$ARTIFACTORY_USERNAME" ] && [ -z "$ARTIFACTORY_PASSWORD" ]; then
    echo "ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD must be set"
    exit 1
fi


oc create secret docker-registry my-registry --docker-server=cp.stg.icr.io  "--docker-username=$CP_STG_USERNAME"  "--docker-password=$CP_STG_PASSWORD" --docker-email=unused --dry-run=client -o jsonpath={'.data.\.dockerconfigjson'} | base64 --decode > /tmp/registry-cp.stg.icr.io.json

oc create secret docker-registry my-registry --docker-server=cp.icr.io  "--docker-username=$CP_USERNAME"  "--docker-password=$CP_PASSWORD" --docker-email=unused --dry-run=client -o jsonpath={'.data.\.dockerconfigjson'} | base64 --decode > /tmp/registry-cp.icr.io.json

oc create secret docker-registry my-registry --docker-server=docker.io  "--docker-username=$DOCKER_USERNAME"  "--docker-password=$DOCKER_PASSWORD" --docker-email=unused --dry-run=client -o jsonpath={'.data.\.dockerconfigjson'} | base64 --decode > /tmp/registry-docker.io.json

oc create secret docker-registry my-registry --docker-server=wasliberty-intops-docker-local.artifactory.swg-devops.com  "--docker-username=$ARTIFACTORY_USERNAME"  "--docker-password=$ARTIFACTORY_PASSWORD" --docker-email=unused --dry-run=client -o jsonpath={'.data.\.dockerconfigjson'} | base64 --decode > /tmp/wasliberty-intops-docker-local.artifactory.swg-devops.com.json

oc create secret docker-registry my-registry --docker-server=hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com  "--docker-username=$ARTIFACTORY_USERNAME"  "--docker-password=$ARTIFACTORY_PASSWORD" --docker-email=unused --dry-run=client -o jsonpath={'.data.\.dockerconfigjson'} | base64 --decode > /tmp/hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com 

oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode > /tmp/pull-secret-global.json

jq -s '.[0] * .[1] * .[2] * .[3] * .[4] * .[5]' /tmp/pull-secret-global.json /tmp/registry-cp.stg.icr.io.json /tmp/registry-cp.icr.io.json /tmp/registry-docker.io.json /tmp/wasliberty-intops-docker-local.artifactory.swg-devops.com.json /tmp/hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com > /tmp/pull-secret-merged.json

echo "Updating global pull secret"
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/pull-secret-merged.json

echo "Deploying ImageContentSourcePolicy"
oc apply -f - <<-EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
    name: mirror-config
    namespace: default
spec:
    repositoryDigestMirrors:
    - mirrors:
      - cp.stg.icr.io/cp
      - wasliberty-intops-docker-local.artifactory.swg-devops.com/cp
      source: cp.icr.io/cp
    - mirrors:
      - cp.stg.icr.io/cp
      - wasliberty-intops-docker-local.artifactory.swg-devops.com/cp
      source: icr.io/cpopen
    - mirrors:
      - cp.stg.icr.io/cp
      - wasliberty-intops-docker-local.artifactory.swg-devops.com/cp
      source: docker.io/ibmcom
    - mirrors:
      - hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom
      source: quay.io/opencloudio
    - mirrors:
      - hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com/ibmcom
      source: cp.icr.io/cp/cpd
EOF

echo "Adding IBM Operator Catalog"
oc apply -f - <<-EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Operator Catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

# echo "Adding IAF Core Catalog"
# oc apply -f - <<-EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: CatalogSource
# metadata:
#   name: iaf-core-operators
#   namespace: openshift-marketplace
# spec:
#   displayName: IAF Core Operators
#   publisher: IBM
#   sourceType: grpc
#   image: cp.stg.icr.io/cp/ibm-automation-foundation-core-catalog:1.0.2
#   updateStrategy:
#     registryPoll:
#       interval: 45m
#   priority: 100
# EOF
