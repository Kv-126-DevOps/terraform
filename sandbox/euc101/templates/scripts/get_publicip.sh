#!/bin/bash
set -e

eval "$(jq -r '@sh "cluster_name=\(.cluster_name) service=\(.service)"')"

TASK_ARN=$(aws ecs list-tasks \
    --cluster "${cluster_name}" \
    --service-name "${service}" \
    --query 'taskArns[0]' \
    --output text)

ENI=$(aws ecs describe-tasks \
    --cluster "${cluster_name}" \
    --tasks "${TASK_ARN}" \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" --output text)

publicip=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "${ENI}" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)


echo -n "{\"publicip\":\"${publicip}\"}"