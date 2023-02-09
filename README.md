# Templates for deploying on ECS 

## CloudFormation templates to build AWS resources
- Network Stack 
- ECS Resources
- ECS Full Stack

   > https://github.com/doitintl/aws-templates-ecs/tree/main/cloudformation

## CodePipeline template for CI/CD Deployments

The templates build on the resources created by the **CloudFormation** templates

   > https://github.com/doitintl/aws-templates-ecs/tree/main/cicd-pipeline
   
## CloudWatch template for Monitoring

The template builds on the resources created by the `ECS Full Stack` template, but it can be easily modify for an existing cluster

   > https://github.com/doitintl/aws-templates-ecs/tree/main/cloudwatch
   

