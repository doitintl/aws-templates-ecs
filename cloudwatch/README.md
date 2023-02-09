# Monitoring in ECS with CloudWatch Container Insights

## CloudWatch Metrics and Container Insights

By default, ECS will publish some basic metrics to CloudWatch (ie. CPUUtilization and MemoryUtilization) at both the Service and Cluster level. However, these metrics do not provide enough insight into the performance of your cluster.

    https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html

CloudWatch Container Insights can be used to expand on the above and collect, aggregate, and summarize metrics and logs from your containerized applications and microservices. It collects metrics at the Cluster, Service and Task level.

    https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-metrics-ECS.html

## Template to get you started

To expand the observability of your ECS Clusters we have provided you with a CloudFormation template `ec2-intance-cwagent.yaml` that will run a Daemon service with the CloudWatch Agent to collect additional metrics for the EC2 instances in your ECS Clusters, which are not included by CloudWatch Container Insights.

Files in this repository:

- Dockerfile if you were looking to build CloudWatch Agent container for Container Instances

**note:** Your own image instead of the one used in the Template `public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest`

- CloudFormation Template that will deploy a Daemon Service that will run the CWAgent on any Container Instances registered to a specified ECS Cluster

The template will create:
+ TaskDefinition named `cwagent-daemon`
+ a TaskRole named `CWAgentECSTaskRole` with the attached managed policy `CloudWatchAgentServerPolicy`
+ a TaskExecutionRole named `CWAgentECSExecutionRole` with the attached managed policies `CloudWatchAgentServerPolicy` and `AmazonECSTaskExecutionRolePolicy`
+ ECS Daemon Service named `cwagent-daemon-service`

## To run the template

   ```
   aws cloudformation create-stack --stack-name cwAgent --template-body file://ec2-instance-cwagent.yaml --parameters ParameterKey=ClusterName,ParameterValue=<ECS_CLUSTER_NAME> --capabilities CAPABILITY_IAM
   ```
**note:** replace **<ECS_CLUSTER_NAME>** with the name of the cluster you wish to use

#### Enabling ContainerInsights on your account as a defalt

    aws ecs put-account-setting --name "containerInsights" --value "enabled"

    note: only works on clusters created after option is enabled

#### Enabling ContainerInsights for an exiting ECS Cluster

    aws ecs update-cluster-settings --cluster <CLUSTER>  --settings name=containerInsights,value=enabled 

#### To verify if a cluster has been enabled

    aws ecs describe-clusters --cluster <CLUSTER> --include SETTINGS

    reference: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-ECS-cluster.html


## Reviewing metrics on CloudWatch Container Insights

Open the Console:   https://console.aws.amazon.com/cloudwatch/home#cw:dashboard=Home

    Navigate:
    
        Insights > Container Insights > select your cluster

        > Performance monitoring

        > you can choose to view metrics at Cluster, Service, and Task levels

On the dashboard you can see at 'Cluster' level:
    CPUUtilization
    MemoryUtilization
    Network
    DiskUtilization
    ContainerInstanceCount
    TaskCount
    ServiceCount

On the dashboard you can see at 'Service' level:
    CPUUtilization
    MemoryUtilization
    NetworkTX
    NetworkRX
    DiskUtilization
    NumberofDesiredTasks
    NumberofRunningTasks
    NumberofPendingTasks
    NumberofTaskSets
    NumberofDeployments

On the dashboard you can see at 'Task' level:
    CPUUtilization
    MemoryUtilization
    NetworkTX
    NetworkRX
    DiskUtilization
    StorageRead
    StorageWrite

To view all the metrics that can be collected by Container Insights

    https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-metrics-ECS.html
    
## Setup Alarms and Actions for CloudWatch Metrics

For example, to setup an Alarm that monitors the Service's MemoryUtilization and when that metric reaches 80%, perform the Action 

1. Open the Console:   https://console.aws.amazon.com/cloudwatch/home#cw:dashboard=Home

    Navigate:
    
        Insights > Container Insights > select your cluster

        > Performance monitoring

        > ECS Services > <SERVICE>

2. Under MemoryUtilization card, click the options button and select 'View in metrics'

3. on the right hand side of the name of the Service, click the bell icon (Actions column)

Under the 'Metric' section:

    Label = name you want to give the alarm

    Period = it is how often the data is evaluated. by default it is 1 minute

        note: lower than 1 minute is considered 'high resolution' and there are additional charges (review pricing page)

Under the 'Conditions' section:


    Threshold type: choose 'static' to define a threshold value

    Whenever <SERVICE> is: choose 'Greater'

    than: enter '80'

Under the 'Notification' section:

    Alarm state trigger: choose 'In Alarm'

    Send a notification to the following SNS topic: choose 'Create a new topic'

    Email endpoints that will receive notification:

        myemail@domain.com

    > click 'Create Topic'

    > Enter a name '<SERVICE> has reached 80% memory utilization'

        note: an email will be sent to you from SNS service asking you to click a link to confirm the subscription to the 'Topic'

    Full details on Creating Alarm/Actions

        https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html

## Querying ECS logs 

1. open the console https://console.aws.amazon.com/cloudwatch/home#logs-insights:

2. select the 'Log Group'

    should be similar to:

        /aws/ecs/containerinsights/<CLUSTER>/performance 

3. Run queries and view the outputs in Graphs

Query CPU and Memory Utilization by TaskID

    `stats avg(CpuUtilized) as CPU, avg(MemoryUtilized) as Mem by TaskId, ContainerName
| sort Mem, CPU desc`

Query like to view a table of number of tasks running in each Service

    `stats count_distinct(TaskId) as Number_of_Tasks by ServiceName
`

Query average CPU and average Memory utilization per Task (every 5 minutes)

    `stats avg(MemoryUtilized) as Avg_Memory, avg(CpuUtilized) as Avg_CPU by bin(5m)
| filter Type="Task"
`
To view the graph, click on 'Visualization' tab

Sample queries:
    
    https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch-metrics-insights-queryexamples.html#cloudwatch-metrics-insights-queryexamples-ECS

    https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-view-metrics.html#Container-Insights-CloudWatch-Logs-Insights-example

Query Syntax reference guide:

    https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html


