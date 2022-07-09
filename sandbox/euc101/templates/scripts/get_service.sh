#!/bin/bash
set -e

eval "$(jq -r '@sh "hosted_zone=\(.hosted_zone) service=\(.service)"')"

service_host=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone --query "ResourceRecordSets[?Name == '$service']" | jq '.[].ResourceRecords[].Value' --raw-output | awk '{print $NF}')

echo -n "{\"service_host\":\"${service_host}\"}"