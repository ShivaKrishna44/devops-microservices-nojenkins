# AWS CloudWatch & Lambda — Interview Q&A with Examples

---

## Part 1: AWS CloudWatch

### What is CloudWatch?

> "CloudWatch is AWS's monitoring and observability service. It collects metrics, logs, and events from all AWS services and your applications. Think of it as your centralized dashboard for everything running in AWS."

**Three pillars:**
| Pillar | What It Does | Example |
|---|---|---|
| Metrics | Numbers over time | CPU at 75%, 200 requests/sec |
| Logs | Text output from services | Application errors, access logs |
| Alarms | Alerts when thresholds breach | "CPU > 80% for 5 minutes → page on-call" |

---

### How to Configure CloudWatch Alarms

**Example 1: High CPU alarm on EC2**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "HighCPU-OrderService" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:589389425618:alerts-topic \
  --dimensions Name=InstanceId,Value=i-0abc123def456
```

**What this does:** If average CPU > 80% for 2 consecutive 5-minute periods → sends notification to SNS topic → Slack/email alert.

---

**Example 2: ALB 5xx errors alarm (Terraform)**

```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "ALB-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 5xx errors in 1 minute"

  dimensions = {
    LoadBalancer = "app/vosukula-shared-alb/abc123"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

**Example 3: EKS Pod restart alarm**

```hcl
resource "aws_cloudwatch_metric_alarm" "pod_restarts" {
  alarm_name          = "EKS-PodRestarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Maximum"
  threshold           = 3

  dimensions = {
    ClusterName = "expense-dev"
    Namespace   = "order-service"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

### Custom Metrics — Send Your Own Data to CloudWatch

**Example: Push custom metric from Python app**

```python
import boto3

cloudwatch = boto3.client('cloudwatch', region_name='us-east-1')

# Send custom metric: orders processed per minute
cloudwatch.put_metric_data(
    Namespace='MyApp/OrderService',
    MetricData=[
        {
            'MetricName': 'OrdersProcessed',
            'Value': 42,
            'Unit': 'Count',
            'Dimensions': [
                {'Name': 'Environment', 'Value': 'production'},
                {'Name': 'Service', 'Value': 'order-service'}
            ]
        }
    ]
)
```

**Then create alarm on custom metric:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "LowOrderRate" \
  --namespace "MyApp/OrderService" \
  --metric-name "OrdersProcessed" \
  --statistic Average \
  --period 300 \
  --threshold 5 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 3 \
  --alarm-actions arn:aws:sns:us-east-1:589389425618:alerts-topic
```

**What this does:** If orders drop below 5/min for 15 minutes → something is wrong → alert.

---

### CloudWatch vs Prometheus+Grafana

| Aspect | CloudWatch | Prometheus + Grafana |
|---|---|---|
| Best for | AWS service metrics (EC2, RDS, ALB) | Kubernetes/application metrics |
| Custom metrics | `put_metric_data` API | `/metrics` endpoint scrape |
| Cost | Per metric, per alarm | Free (self-hosted) |
| Dashboards | Built-in | Grafana (richer) |
| In my project | ALB health, node metrics, billing | Pod metrics, app latency, custom PromQL |

**My approach:** Use BOTH — CloudWatch for AWS infra, Prometheus for Kubernetes/app layer.

---

### Interview Answer

> "I use CloudWatch for AWS service-level monitoring — ALB error rates, RDS connections, EC2 CPU. I set up alarms with SNS notifications to Slack. For custom business metrics like orders per minute, I push data via the SDK. For Kubernetes-level monitoring, I use Prometheus + Grafana because it integrates better with pod metrics and PromQL gives more flexibility than CloudWatch Insights."

---

## Part 2: AWS Lambda

### What is Lambda?

> "Lambda is serverless compute. You upload code, AWS runs it when triggered. You don't manage servers — no EC2, no patching, no scaling. You pay only when it runs (per millisecond)."

**Triggers:**
| Trigger | Example Use Case |
|---|---|
| API Gateway | REST API endpoint |
| S3 Event | Process file when uploaded |
| SQS | Process messages from queue |
| EventBridge | Scheduled task (cron job) |
| CloudWatch Alarm | Auto-remediation on alert |
| DynamoDB Streams | React to database changes |

---

### Lambda Example: Auto-remediate unhealthy ECS task

```python
import boto3

def lambda_handler(event, context):
    """
    Triggered by CloudWatch alarm when ECS task is unhealthy.
    Restarts the service to recover.
    """
    ecs = boto3.client('ecs')
    
    cluster = 'production'
    service = 'order-service'
    
    # Force new deployment (restarts all tasks)
    response = ecs.update_service(
        cluster=cluster,
        service=service,
        forceNewDeployment=True
    )
    
    return {
        'statusCode': 200,
        'body': f'Restarted {service} in {cluster}'
    }
```

---

### Lambda Example: Rotate secrets automatically

```python
import boto3
import json

def lambda_handler(event, context):
    """
    Triggered by Secrets Manager rotation schedule.
    Generates new DB password and updates RDS.
    """
    secrets = boto3.client('secretsmanager')
    rds = boto3.client('rds')
    
    secret_id = event['SecretId']
    
    # Generate new password
    new_password = secrets.get_random_password(
        PasswordLength=32,
        ExcludeCharacters='/@"'
    )['RandomPassword']
    
    # Update RDS
    rds.modify_db_instance(
        DBInstanceIdentifier='production-db',
        MasterUserPassword=new_password
    )
    
    # Store new password in Secrets Manager
    secrets.put_secret_value(
        SecretId=secret_id,
        SecretString=json.dumps({'password': new_password})
    )
    
    return {'status': 'rotated'}
```

---

### What Are Cold Starts?

> "A cold start happens when Lambda has no warm container ready. AWS must: download your code → start the runtime → initialize your handler. First request is slow (100ms-3s), subsequent requests are fast (1-10ms)."

```
Request 1 (cold):  Download code → Start runtime → Init → Execute  = 800ms
Request 2 (warm):  Execute                                          = 5ms
Request 3 (warm):  Execute                                          = 4ms
... 15 min idle ...
Request 4 (cold):  Download code → Start runtime → Init → Execute  = 800ms
```

**Cold start happens when:**
- First invocation (no container exists)
- After ~15 minutes of no traffic (container recycled)
- When scaling out (new concurrent container needed)
- After code deployment (new version, all containers cold)

---

### How to Minimize Cold Starts

| Method | How | Reduction |
|---|---|---|
| **Provisioned Concurrency** | Pre-warm N containers, always ready | Eliminates cold starts completely |
| **Smaller package size** | Remove unused dependencies, use layers | Faster download = faster cold start |
| **Use lighter runtime** | Python/Node.js (200ms) vs Java (3-5s) | 10x faster cold start |
| **Keep functions warm** | Scheduled ping every 5 min | Prevents container recycling |
| **Init outside handler** | DB connections in global scope | One-time cost, reused across invocations |
| **ARM64 (Graviton)** | Switch from x86 to arm64 | 20% faster startup + cheaper |

---

**Example: Provisioned Concurrency (Terraform)**

```hcl
resource "aws_lambda_function" "order_processor" {
  function_name = "order-processor"
  runtime       = "python3.11"
  handler       = "app.handler"
  filename      = "lambda.zip"
  memory_size   = 256
  timeout       = 30
  architectures = ["arm64"]  # Graviton — faster + cheaper
}

# Keep 5 containers always warm — zero cold starts for first 5 concurrent requests
resource "aws_lambda_provisioned_concurrency_config" "warm" {
  function_name                  = aws_lambda_function.order_processor.function_name
  provisioned_concurrent_executions = 5
  qualifier                      = aws_lambda_function.order_processor.version
}
```

---

**Example: Init outside handler (best practice)**

```python
import boto3
import os

# ✅ GOOD: Initialized ONCE on cold start, reused for all warm invocations
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    # ✅ Uses already-initialized connection (no cold start penalty here)
    response = table.get_item(Key={'order_id': event['order_id']})
    return response['Item']
```

vs

```python
def lambda_handler(event, context):
    # ❌ BAD: Creates new connection on EVERY invocation
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('orders')
    response = table.get_item(Key={'order_id': event['order_id']})
    return response['Item']
```

---

**Example: Keep warm with scheduled ping**

```hcl
# EventBridge rule — pings Lambda every 5 minutes
resource "aws_cloudwatch_event_rule" "warmup" {
  name                = "lambda-warmup"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "warmup" {
  rule = aws_cloudwatch_event_rule.warmup.name
  arn  = aws_lambda_function.order_processor.arn
  input = jsonencode({ "warmup": true })
}

# Lambda ignores warmup events:
# if event.get('warmup'): return {'statusCode': 200}
```

---

### Cold Start Duration by Runtime

| Runtime | Avg Cold Start | Notes |
|---|---|---|
| Python 3.11 | 150-300ms | Best for most use cases |
| Node.js 20 | 100-200ms | Fastest cold start |
| Go | 50-100ms | Compiled, tiny binary |
| Java 21 | 2-5 seconds | JVM startup is heavy |
| .NET 8 | 500ms-2s | Better with AOT compilation |

**For trading systems (IC Markets):** Use Python/Node.js for latency-critical Lambdas. If Java required, use SnapStart (pre-initializes JVM snapshot).

---

### Interview Answer: CloudWatch + Lambda Together

> "In my project, I use CloudWatch to monitor ALB error rates and EKS node health. When an alarm fires — say 5xx errors spike — it triggers an SNS notification to Slack AND a Lambda function that auto-remediates (restarts the service or scales up). For custom metrics, I push order-processing rates from the app using the CloudWatch SDK, with an alarm that fires if throughput drops below a threshold.
>
> For Lambda cold starts — I minimize them by keeping packages small, initializing connections outside the handler, using Python runtime, and provisioned concurrency for latency-critical functions. In a trading context, I'd use provisioned concurrency with arm64 Graviton for the fastest possible startup."


---

## Part 3: CloudWatch vs Prometheus+Grafana — When to Use Which

### Comparison

| Aspect | CloudWatch | Prometheus + Grafana |
|---|---|---|
| Best for | AWS managed services (RDS, ALB, Lambda) | Kubernetes pods, deployments, custom app metrics |
| K8s support | Needs ContainerInsights addon ($) | Native — built for K8s |
| Custom queries | CloudWatch Insights (limited) | PromQL (powerful, flexible) |
| Alerting | CloudWatch Alarms → SNS | Alertmanager → Slack/email/PagerDuty |
| Dashboards | Basic, preset | Grafana (rich, 1000+ community dashboards) |
| Cost | ~$0.30/metric/month + $0.10/alarm | Free (self-hosted on EKS) |
| Setup | Enable addon, metrics auto-flow | Install kube-prometheus-stack (Helm) |
| Retention | 15 months (paid) | Configurable (local storage) |

---

### My Approach: Use BOTH (Each for Its Strength)

```
CloudWatch handles:
  ├── ALB health checks + 5xx count
  ├── RDS connections, CPU, IOPS
  ├── Lambda invocations, errors, duration
  ├── Billing alerts
  └── AWS service limits

Prometheus + Grafana handles:
  ├── Pod CPU/memory usage
  ├── Deployment replica status
  ├── HPA scaling events
  ├── Container restart counts
  ├── Application custom metrics (/metrics endpoint)
  └── PromQL for complex queries
```

---

### Why Prometheus is Better for EKS

1. **No extra cost** — already installed via kube-prometheus-stack
2. **Instant metrics** — scrapes every 15 seconds (CloudWatch = 1-5 min delay)
3. **PromQL** — can query across namespaces, aggregate by label, calculate rates
4. **Pre-built dashboards** — import by ID (15760, 13770, 12006)
5. **Works without internet** — in-cluster, no AWS API calls needed
6. **Alertmanager** — routes alerts by severity (P1→PagerDuty, P2→Slack, P3→email)

---

### When You Still Need CloudWatch

| Use Case | Why CloudWatch, Not Prometheus |
|---|---|
| RDS database metrics | Can't scrape RDS with Prometheus (no /metrics endpoint) |
| ALB request count + latency | ALB metrics only in CloudWatch |
| Lambda monitoring | Serverless — no persistent pod to scrape |
| Billing alerts | Only CloudWatch has cost data |
| Cross-account monitoring | CloudWatch cross-account dashboards |
| Compliance/audit | CloudTrail + CloudWatch Logs (required for some certifications) |

---

### Setup: Import Grafana Dashboard (1 minute)

```
1. Go to: https://grafana.vosukula.online
2. Left sidebar → Dashboards → Import
3. Enter ID: 15760 → Load
4. Select datasource: Prometheus
5. Click Import
```

**Recommended dashboard IDs:**
| ID | Name | What It Shows |
|---|---|---|
| 15760 | Kubernetes Cluster Monitoring | Nodes, pods, CPU, memory overview |
| 13770 | Kubernetes Pod Metrics | Per-pod CPU, memory, network |
| 12006 | Kubernetes Deployment Metrics | Deployment replicas, rollout status |
| 1860 | Node Exporter Full | Detailed node-level metrics |

---

### Interview Answer

> "For Kubernetes workloads, I use Prometheus + Grafana over CloudWatch because it's free, faster (15-second scrape interval vs 1-5 min), and gives me PromQL for complex queries. I still keep CloudWatch for AWS service metrics that Prometheus can't access — ALB error rates, RDS performance, Lambda invocations, and billing alerts. The combination gives full observability at minimal cost."
