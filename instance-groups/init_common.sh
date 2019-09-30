#!/usr/bin/env bash

set -eo pipefail

yc init

NETWORK_ID=$(yc vpc network create --name yc-auto-network --format json | jq -r .id)

zones=(a b c)

for i in ${!zones[@]}; do
  echo "Creating subnet yc-auto-subnet-$i"
  yc vpc subnet create --name yc-auto-subnet-$i \
  --zone ru-central1-${zones[$i]} \
  --range 192.168.$i.0/24 \
  --network-id ${NETWORK_ID}
done

FOLDER_ID=$(yc config get folder-id)
FOLDER_NAME=$(yc resource-manager folder get ${FOLDER_ID} --format json | jq -r .name)
SERVICE_ACCOUNT_ID=$(yc iam service-account create --name ${FOLDER_NAME} --format json  | jq -r .id)
yc resource-manager folder add-access-binding --role editor --subject serviceAccount:${SERVICE_ACCOUNT_ID} ${FOLDER_ID}

render_template() {
    echo "Rendering " $1
    sed -i '' -e 's/${NETWORK_ID}/'${NETWORK_ID}'/g' -e 's/${SERVICE_ACCOUNT_ID}/'${SERVICE_ACCOUNT_ID}'/g' $1
}

render_template 02/CLI/specification.yaml
render_template 03/specification.yaml