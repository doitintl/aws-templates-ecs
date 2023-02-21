# ELK Stack using AWS OpenSearch

## Requirements
- By default this template uses AMI `ami-0ea0f26a6d50850c5` from `eu-west-1` region to create a Reverse Proxy so you can access your OpenSearch Dashboard. 

    note: To find another region you can run the command below and replace the parameter for for  `ProxyInstanceAMIID` in template

`aws ec2 describe-images --owners self amazon --filters "Name=name,Values=amzn2-ami-kernel-5.10-hvm-2.0.20220912.1-x86_64-gp2" --query 'Images[*].ImageId' --output text`

## To create the stack

   ```
   aws cloudformation create-stack --stack-name OpenSearch --template-body file://ecs_opensearch.yaml
   ```

   **note:** the stack creation will take approximately 30 minutes

Resources that will be created:
- ECS
    + Cluster, Fargate Service and Security Groups
    + TaskDefinition with sample web app and the Firelens container 'log_router'
    + IAM TaskRole and TaskExecutionRoles
    + Application Load Balander with Target Group and Security Groups

- Networking
    + 3 public subnets and 3 private subnets 
    + Routes for subnets and attachments
    + Internet Gateway for the public subnets
    + NAT Gateway for the private subnets

- EC2 
    + Reverse Proxy Instance to securely access your OpenSearch dashboard using HTTPS
    + Security Group
    + IAM instance role, allows SSM Session Manager access

    `https://docs.aws.amazon.com/opensearch-service/latest/developerguide/dashboards.html#dashboards-access`

- OpenSearch
    + Creates domain with 3 x **t3.small.search** instances for high availability but you can reduce this to a single instance in the template if required
    + IAM OpenSearch Service Role


- Lambda
    + function to create the password for the OpenSearch user **aosadmin**
    + function to retrive the PublicIP for the OpenSearch dashboard `https://<PUBLIC-IP>/_dashboards`
    + IAM Roles

## Allow a user to perform actions in the OpenSearch Cluster

This must be done inside the OpenSearch Dashboard

    https://<PUBLIC-IP>/_dashboards/app/security-dashboards-plugin#/roles

For simplicity while testing you can use the ARN of the `OpenSearchTaskRole` as the backend role of the `aosadmin` user which has full access in the OpenSearch cluster. In production it is recommended to have strict permission to only allow the access/actions you require.

`https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac.html`


## Simulate traffic on the ECS Service to generate logs

1. Install amazon-extras repo on an Amazon Linux 2 instance
`sudo amazon-linux-extras install epel -y`

2. Install Siege
`sudo yum -y install siege`

3. simulate traffic using Siege tool. You can get the ALB_URL in the Stack's Outputs tab in CloudFormation

    note: The following command will run 200 concurrent connections to the URL of your Load Balancer. Run it for a few minutes and then press control-C to exit

    `siege -c 200 -i <ALB_URL>`


## Troubleshooting

Errors found in the ECS Console 

    ECS > Cluster > Service > Logs

`reason": "no permissions for [indices:data/write/bulk] and User [name=arn:aws:iam::xxxxxxx:role/OpenSearchTaskRole, backend_roles=[arn:aws:iam::xxxxxxx:role/OpenSearchTaskRole]`

> you can fix this by linking the 'arn:aws:iam::xxxxxxx:role/OpenSearchTaskRole' to an OpenSearch user as a 'Backend Role'. The user must have the permissions to 'write/bulk/*' and access/create the index you wish to use



## References:

ECS Custom Log Routing:
`https://docs.aws.amazon.com/AmazonECS/latest/userguide/using_firelens.html`

Sample Task Definition for OpenSearch:
`https://github.com/aws-samples/amazon-ecs-firelens-examples/blob/mainline/examples/fluent-bit/amazon-opensearch/task-definition.json`

OpenSearch Documentation:
`https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html`

OpenSearch Permissions to allow user to use cluster:
`https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac.html`

Siege:
`https://www.techrepublic.com/article/how-to-benchmark-website-with-siege-command-line-tool/`

Alternate configuration of OpenSearch stack with Kinesis data transformation:
`https://github.com/aws-samples/unified-log-aggregation-and-analytics`
