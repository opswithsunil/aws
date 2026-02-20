# AWS ECS Step Scaling Automation Script

This script automates the configuration of **Application Auto Scaling** for an Amazon ECS Service using **Step Scaling** policies. It dynamically discovers the first available ECS Cluster and Service in the defined region and configures scaling targets, scaling policies, and CloudWatch alarms for both CPU and Memory utilization.

## 📋 Features

* **Dynamic Discovery:** Automatically fetches the first ECS Cluster and Service ARN available in the account.
* **Scalable Target Registration:** Registers the ECS service as a scalable target with defined Minimum and Maximum capacity.
* **Step Scaling Policies:**
    * **CPU Scale Out:** Increases capacity when CPU utilization is high.
    * **CPU Scale In:** Decreases capacity when CPU utilization is low.
    * **Memory Scale Out:** Increases capacity when Memory utilization is high.
    * **Memory Scale In:** Decreases capacity when Memory utilization is low.
* **CloudWatch Alarms:** Automatically creates the necessary alarms to trigger the scaling policies.

## 🛠 Prerequisites

Before running this script, ensure you have the following:

1.  **AWS CLI:** Installed and configured with appropriate permissions.
    ```bash
    aws --version
    ```
2.  **Permissions:** The AWS profile used must have permissions for:
    * `ecs:ListClusters`, `ecs:ListServices`
    * `application-autoscaling:*`
    * `cloudwatch:PutMetricAlarm`
3.  **Active ECS Service:** At least one running ECS Cluster and Service.

## ⚙️ Configuration

The following variables are defined at the top of the script and can be modified to suit your environment:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `REGION` | `us-east-1` | The AWS Region where the ECS cluster resides. |
| `MIN_CAPACITY` | `1` | The minimum number of tasks to maintain. |
| `MAX_CAPACITY` | `10` | The maximum number of tasks allowed. |

## 📊 Scaling Logic

The script implements **Step Scaling** with the following thresholds:

### CPU Utilization

| Action | Alarm Threshold | Evaluation | Adjustment | Cooldown |
| :--- | :--- | :--- | :--- | :--- |
| **Scale Out** | **≥ 70%** | 1 Period (60s) | +1 Task (Moderate)<br>+2 Tasks (High Load) | 60s |
| **Scale In** | **< 40%** | 2 Periods (60s) | -1 Task | 180s |

### Memory Utilization

| Action | Alarm Threshold | Evaluation | Adjustment | Cooldown |
| :--- | :--- | :--- | :--- | :--- |
| **Scale Out** | **≥ 80%** | 1 Period (60s) | +1 Task | 60s |
| **Scale In** | **< 50%** | 2 Periods (60s) | -1 Task | 180s |

## 🚀 Usage

1.  **Download the script:** Save the code as `setup_scaling.sh`.
2.  **Make it executable:**
    ```bash
    chmod +x setup_scaling.sh
    ```
3.  **Run the script:**
    ```bash
    ./setup_scaling.sh
    ```

## ⚠️ Important Notes

* **Cluster Selection:** The script uses `aws ecs list-clusters --query 'clusterArns[0]'`. It will automatically select the **first** cluster returned by the API. If you have multiple clusters, modify the `CLUSTER` variable assignment in the script to target a specific name.
* **Service Selection:** Similarly, it selects the **first** service in that cluster (`serviceArns[0]`).
* **Cost:** This script creates CloudWatch Alarms which may incur a small monthly cost per alarm.

## 🔍 Troubleshooting

**Error: "Unable to locate credentials"**
Ensure your AWS CLI is configured:
```bash
aws configure