#!/usr/bin/env bash
set -Eeuo pipefail

export WATCHED_EVENTS="AddUserToGroup,\
CreateAccessKey,\
CreateGroup,\
CreatePolicy,\
CreateRole,\
PutGroupPolicy,\
PutRolePolicy,\
PutUserPolicy,\
ConsoleLogin,\
SwitchRole,\
StopLogging,\
CreateNetworkAclEntry,\
CreateRoute,\
AuthorizeSecurityGroupEgress,\
AuthorizeSecurityGroupIngress,\
RevokeSecurityGroupEgress,\
RevokeSecurityGroupIngress,\
ApplySecurityGroupsToLoadBalancer,\
SetSecurityGroups,\
AuthorizeDBSecurityGroupIngress,\
CreateDBSecurityGroup,\
DeleteDBSecurityGroup,\
RevokeDBSecurityGroupIngress"

aws cloudformation deploy \
    --stack-name kbc-cloudtrail-slack-hook-resources \
    --template-file ./cf-stack.json \
    --no-fail-on-empty-changeset \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      ServiceName=$KEBOOLA_STACK \
      Stage=prod

export CLOUDFORMATION_ROLE_ARN=`aws cloudformation describe-stacks \
  --stack-name kbc-cloudtrail-slack-hook-resources \
  --query "Stacks[0].Outputs[?OutputKey=='ServerlessCloudFormationRole'].OutputValue" \
  --output text`

export LAMBDA_EXECUTION_ROLE_ARN=`aws cloudformation describe-stacks \
  --stack-name kbc-cloudtrail-slack-hook-resources \
  --query "Stacks[0].Outputs[?OutputKey=='ServerlessLambdaExecutionRole'].OutputValue" \
  --output text`

export REGION=`aws cloudformation describe-stacks \
  --stack-name kbc-cloudtrail-slack-hook-resources \
  --query "Stacks[0].Outputs[?OutputKey=='Region'].OutputValue" \
  --output text`

export S3_DEPLOYMENT_BUCKET=`aws cloudformation describe-stacks \
  --stack-name kbc-cloudtrail-slack-hook-resources \
  --query "Stacks[0].Outputs[?OutputKey=='ServerlessDeploymentS3Bucket'].OutputValue" \
  --output text`

docker build --tag kbc-cloudtrail-slack-hook .
docker run --rm kbc-cloudtrail-slack-hook yarn test:lint
docker run --rm kbc-cloudtrail-slack-hook yarn test:unit

echo "Deploy start."
docker run --rm \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN \
    -e CLOUDFORMATION_ROLE_ARN \
    -e LAMBDA_EXECUTION_ROLE_ARN \
    -e REGION \
    -e WATCHED_EVENTS \
    -e KEBOOLA_STACK \
    -e "STAGE=prod" \
    -e "SERVICE_NAME=${KEBOOLA_STACK}" \
    -e "SLACK_URL=${CLOUDTRAIL_SLACK_HOOK_SLACK_URL}" \
    -e "TIME_ZONE=${CLOUDTRAIL_SLACK_HOOK_TIME_ZONE}" \
    -e "S3_DEPLOYMENT_BUCKET=${S3_DEPLOYMENT_BUCKET}" \
    kbc-cloudtrail-slack-hook serverless deploy

