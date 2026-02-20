#!/bin/bash
set -e

REGION="us-east-1"
MIN_CAPACITY=1
MAX_CAPACITY=10

export AWS_DEFAULT_REGION=$REGION

echo "Discovering ECS cluster and service..."

CLUSTER=$(aws ecs list-clusters --query 'clusterArns[0]' --output text | awk -F/ '{print $2}')
SERVICE=$(aws ecs list-services --cluster $CLUSTER --query 'serviceArns[0]' --output text | awk -F/ '{print $3}')

echo "Cluster: $CLUSTER"
echo "Service: $SERVICE"

RESOURCE_ID="service/$CLUSTER/$SERVICE"

echo "Registering scalable target..."
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id $RESOURCE_ID \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity $MIN_CAPACITY \
  --max-capacity $MAX_CAPACITY

echo "Creating scaling policies..."

CPU_OUT_ARN=$(aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id $RESOURCE_ID \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scale-out \
  --policy-type StepScaling \
  --step-scaling-policy-configuration '{
    "AdjustmentType": "ChangeInCapacity",
    "Cooldown": 60,
    "MetricAggregationType": "Average",
    "StepAdjustments": [
      { "MetricIntervalLowerBound": 0, "MetricIntervalUpperBound": 10, "ScalingAdjustment": 1 },
      { "MetricIntervalLowerBound": 10, "ScalingAdjustment": 2 }
    ]
  }' --query PolicyARN --output text)

CPU_IN_ARN=$(aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id $RESOURCE_ID \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scale-in \
  --policy-type StepScaling \
  --step-scaling-policy-configuration '{
    "AdjustmentType": "ChangeInCapacity",
    "Cooldown": 180,
    "MetricAggregationType": "Average",
    "StepAdjustments": [
      { "MetricIntervalUpperBound": 0, "ScalingAdjustment": -1 }
    ]
  }' --query PolicyARN --output text)

MEM_OUT_ARN=$(aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id $RESOURCE_ID \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name mem-scale-out \
  --policy-type StepScaling \
  --step-scaling-policy-configuration '{
    "AdjustmentType": "ChangeInCapacity",
    "Cooldown": 60,
    "MetricAggregationType": "Average",
    "StepAdjustments": [
      { "MetricIntervalLowerBound": 0, "ScalingAdjustment": 1 }
    ]
  }' --query PolicyARN --output text)

MEM_IN_ARN=$(aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id $RESOURCE_ID \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name mem-scale-in \
  --policy-type StepScaling \
  --step-scaling-policy-configuration '{
    "AdjustmentType": "ChangeInCapacity",
    "Cooldown": 180,
    "MetricAggregationType": "Average",
    "StepAdjustments": [
      { "MetricIntervalUpperBound": 0, "ScalingAdjustment": -1 }
    ]
  }' --query PolicyARN --output text)

echo "Creating CloudWatch alarms..."

aws cloudwatch put-metric-alarm \
  --alarm-name ecs-cpu-high \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 70 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE \
  --alarm-actions $CPU_OUT_ARN

aws cloudwatch put-metric-alarm \
  --alarm-name ecs-cpu-low \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 40 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE \
  --alarm-actions $CPU_IN_ARN

aws cloudwatch put-metric-alarm \
  --alarm-name ecs-mem-high \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE \
  --alarm-actions $MEM_OUT_ARN

aws cloudwatch put-metric-alarm \
  --alarm-name ecs-mem-low \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 50 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=ClusterName,Value=$CLUSTER Name=ServiceName,Value=$SERVICE \
  --alarm-actions $MEM_IN_ARN

echo "✅ ECS Auto Scaling fully configured"

