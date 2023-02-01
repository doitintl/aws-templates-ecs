# Deploy an ECS Cluster with AWS CloudFormation

Use the sample AWS CloudFormation Templates to create your own ECS Cluster with an underlying Network Stack.

## Resources created by the templates

- VPC, 2 Public Subnets, RouteTable and Internet Gateway
- ECS Cluster
- ECS IAM Roles
- Security Groups
- Load Balancer and "Dummy" Target Group for the Load Balancer

## Prerequisites

- An AWS account
- IAM user/role with permissions to create the AWS resources
- AWS CLI

## How to use the templates

1. Clone this repository

2. Create the **NetworkStack**

   ```
   aws cloudformation create-stack --stack-name NetworkStack --template-body file://networking_infra.yaml
   ```

3. Create the **ECS Cluster Stack**

   ```
   aws cloudformation create-stack --stack-name myECSCluster --template-body file://ecs_resources.yaml --parameters NetworkStack
   ```
  
  **note:** The name of the NetworkStack was used as a parameter in the ECS Cluster Stack. If the name is changed in NetworkStack you must use same in the parameter of the ECS Cluster Stack.
  
# Additional Resources

AWS CLI - https://docs.aws.amazon.com/cli/latest/reference/cloudformation/index.html

ECS Workshop - https://ecsworkshop.com/

AWS CloudFormation Workshop - https://catalog.workshops.aws/cfn101/en-US

AWS CloudFormation Lab - https://mng.workshop.aws/cloudformation.html
