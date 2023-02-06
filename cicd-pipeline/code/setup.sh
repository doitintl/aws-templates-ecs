#!/bin/bash

# set AWS account number and region

export AWS_ID=$(aws sts get-caller-identity --output text --query Account)
export REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
AWS_ID="$(aws sts get-caller-identity --query Account --output text)"

# create ECR repository

aws ecr create-repository \
    --repository-name images-repo \
    --image-scanning-configuration scanOnPush=true


# save the repository as a variable and output variable

ECR_REPO=$(aws ecr describe-repositories | jq -r .repositories[].repositoryUri | grep images-repo)

echo $ECR_REPO > outputs.txt

# create codecommit repo and save as variable and output variable

aws codecommit create-repository --repository-name code-repo 

CODE_COMMIT_REPO=$(aws codecommit get-repository --repository-name code-repo | jq -r .repositoryMetadata.cloneUrlHttp)
echo $CODE_COMMIT_REPO >> outputs.txt

# create variables for the resources in the CloudFormation 
VPC_ID=$(aws cloudformation describe-stacks --stack-name NetworkStack --query "Stacks[0].Outputs[?OutputKey == 'VPCId'].OutputValue" --output text)
SUBNET_ONE=$(aws cloudformation describe-stacks --stack-name NetworkStack --query "Stacks[0].Outputs[?OutputKey == 'PublicSubnetOne'].OutputValue" --output text)
SUBNET_TWO=$(aws cloudformation describe-stacks --stack-name NetworkStack --query "Stacks[0].Outputs[?OutputKey == 'PublicSubnetTwo'].OutputValue" --output text)
LISTENER=$(aws cloudformation describe-stacks --stack-name myECSCluster --query "Stacks[0].Outputs[?OutputKey == 'PublicListener'].OutputValue" --output text)
CLUSTER=$(aws cloudformation describe-stacks --stack-name myECSCluster --query "Stacks[0].Outputs[?OutputKey == 'ClusterName'].OutputValue" --output text)
EXEC_ROLE=$(aws cloudformation describe-stacks --stack-name myECSCluster --query "Stacks[0].Outputs[?OutputKey == 'ECSTaskExecutionRole'].OutputValue" --output text)
FARGATE_SG=$(aws cloudformation describe-stacks --stack-name myECSCluster --query "Stacks[0].Outputs[?OutputKey == 'FargateContainerSecurityGroup'].OutputValue" --output text)
ALB_URL=$(aws cloudformation describe-stacks --stack-name myECSCluster --query "Stacks[0].Outputs[?OutputKey == 'ExternalUrl'].OutputValue" --output text)

echo $VPC_ID >> outputs.txt
echo $SUBNET_ONE >> outputs.txt
echo $SUBNET_TWO >> outputs.txt
echo $LISTENER >> outputs.txt
echo $CLUSTER >> outputs.txt
echo $EXEC_ROLE >> outputs.txt
echo $FARGATE_SG >> outputs.txt
echo $ALB_URL >> outputs.txt

# add repo URI to buildspec.yml
sed -i "s%<IMAGE_REPO_URI>%$ECR_REPO%" buildspec.yml

#create target group

TG_ARN=$(aws elbv2 create-target-group \
  --name webapp-tg \
  --port 80 \
  --protocol HTTP \
  --health-check-path / \
  --health-check-timeout-seconds 3 \
  --health-check-interval-seconds 5 \
  --healthy-threshold-count 2 \
  --target-type ip \
  --vpc-id $VPC_ID \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

echo $TG_ARN >> outputs.txt

# modify deregistration delay to 5 seconds
aws elbv2 modify-target-group-attributes \
  --target-group-arn $TG_ARN \
  --attributes "Key=deregistration_delay.timeout_seconds,Value=5"


#creating listerner rules
cat <<EoF >conditions-pattern.json
[
    {
        "Field": "path-pattern",
        "PathPatternConfig": {
            "Values": ["/*"]
        }
    }
]
EoF
cat <<EoF >actions.json
[
    {
        "Type": "forward",
        "ForwardConfig": {
            "TargetGroups": [ { "TargetGroupArn": "$TG_ARN" } ]
        }
    }
]
EoF

# listener rule
LISTENER_RULE=$( aws elbv2 create-rule --listener-arn $LISTENER \
--priority 2 \
--conditions file://conditions-pattern.json \
--actions file://actions.json \
--query "Rules[0].RuleArn" \
--output text \
)

echo $LISTENER_RULE >> outputs.txt

#create ecs log group
aws logs create-log-group --log-group-name /ecs/cicd-example-app

# remove hidden .git file to prevent conflicts with codecommit

rm -rf .git

# create task definition with the name "cicdtaskdef"

cat > task-definition.json <<EOF
{
    "executionRoleArn": "${EXEC_ROLE}",
    "family": "cicdtaskdef", 
    "networkMode": "awsvpc", 
    "containerDefinitions": [
        {
            "name": "web-server", 
            "image": "${AWS_ID}.dkr.ecr.${REGION}.amazonaws.com/images-repo", 
            "portMappings": [
                {
                    "containerPort": 80, 
                    "hostPort": 80, 
                    "protocol": "tcp"
                }
            ], 
            "logConfiguration": { 
            "logDriver": "awslogs",
            "options": { 
               "awslogs-group" : "/ecs/cicd-example-app",
               "awslogs-region": "${REGION}",
               "awslogs-stream-prefix": "ecs"
            }
         },
            "essential": true, 
            "entryPoint": [], 
            "command": []
        }
    ], 
    "requiresCompatibilities": [
        "FARGATE"
    ], 
    "cpu": "256", 
    "memory": "512"
}
EOF

aws ecs register-task-definition --cli-input-json file://task-definition.json

# save TD and clusterARN variable
TD=$(aws ecs list-task-definitions --family-prefix cicdtaskdef | jq -r '.taskDefinitionArns | last')
CLUSTER_ARN=$(aws ecs describe-clusters --cluster "$CLUSTER" | jq -r '.clusters[0].clusterArn')

# create MyService ECS Service

cat > service.json <<EOF
{
  "serviceName": "MyService", 
  "launchType": "FARGATE", 
  "loadBalancers": [
      {
          "targetGroupArn": "${TG_ARN}", 
          "containerName": "web-server",
          "containerPort": 80
      }
  ], 
  "desiredCount": 2, 
  "cluster": "${CLUSTER_ARN}", 
  "deploymentConfiguration": {
      "maximumPercent": 200, 
      "minimumHealthyPercent": 50
  }, 
  "healthCheckGracePeriodSeconds": 2, 
  "schedulingStrategy": "REPLICA", 
  "taskDefinition": "${TD}",
  "networkConfiguration": {
    "awsvpcConfiguration": {
        "subnets": [
            "${SUBNET_ONE}", 
            "${SUBNET_TWO}"
        ], 
        "securityGroups":[
            "$FARGATE_SG"
        ],
        "assignPublicIp": "ENABLED"
    }
  }
}
EOF

aws ecs create-service --cli-input-json file://service.json


# log group for CodeBuild 

aws logs create-log-group --log-group-name /codebuild/web-server

# create trust policy for codebuild
cat <<EoF > codebuild_trust_policy_doc.json
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EoF

# codebuild role
CODEBUILD_ROLE=codebuildRole
CODEBUILD_ROLE_ARN=$(aws iam create-role \
--role-name $CODEBUILD_ROLE \
--assume-role-policy-document file://codebuild_trust_policy_doc.json \
--query Role.Arn \
--output text \
)

# attach policy to AWS Managed policy
aws iam attach-role-policy \
--role-name $CODEBUILD_ROLE \
--policy-arn arn\:aws\:iam::aws\:policy/AmazonEC2ContainerRegistryPowerUser

echo $CODEBUILD_ROLE >> outputs.txt
echo $CODEBUILD_ROLE_ARN >> outputs.txt
