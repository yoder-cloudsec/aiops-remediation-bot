# EKS AIOps Remediation Bot

Event-driven, guarded remediation for an existing Amazon EKS workload. An SNS alert triggers an AWS Lambda function that validates the alert, performs a fixed Kubernetes rollout restart, checks the rollout result, and uses Amazon Bedrock to produce a concise incident summary.

## Architecture

```text
Kubernetes alert
      │
      ▼
     SNS
      │
      ▼
AWS Lambda (Python 3.12 + kubectl)
      │  Validate alert / enforce cooldown
      │  Authenticate to EKS using an STS-signed token
      ▼
EKS Deployment ── rollout restart + status check
      │
      └── Pod state before/after ──► Amazon Bedrock (Nova Micro)
                                      │
                                      ▼
                              Incident summary
```

The remediation is deterministic: Bedrock does not choose or execute the action. It receives the observed alert and remediation results and turns them into a short, plain-English incident note.

## Guardrails

- Only firing `KubeDeploymentReplicasMismatch` alerts are accepted.
- The namespace and Deployment are fixed in Lambda configuration; the alert payload cannot select a target.
- A 15-minute cooldown is checked against the Deployment's `kubectl.kubernetes.io/restartedAt` annotation. If restart history cannot be read or parsed, the function fails closed and skips remediation.
- EKS authentication uses a short-lived token signed through AWS STS; the token is not logged or sent to Bedrock.
- Bedrock summarization is best-effort. A model/API failure does not change the remediation decision; raw command results remain available in the Lambda response and logs.

## Stack

AWS Lambda (Python 3.12) · Amazon EKS · Amazon SNS · Amazon Bedrock (Nova Micro) · Terraform · AWS STS · `kubectl`

## Configuration and deployment

### Prerequisites

- AWS CLI credentials and IAM permissions to deploy the Terraform resources. The Lambda execution role needs permission to invoke the configured Bedrock model.
- Terraform and an existing EKS cluster. This configuration references an existing cluster; it does not create one.
- EKS access/RBAC for the Lambda execution role to read the target Deployment and Pods and perform the target Deployment restart.
- An existing S3 bucket for the Terraform backend.
- A compatible Linux/amd64 `kubectl` binary at `remediation-bot/functions/remediate/kubectl`, with executable permissions. The binary is intentionally excluded by `.gitignore` but is included in the Lambda deployment archive.

### Configure

1. In `remediation-bot/main.tf`, set the S3 backend bucket/key/region and the existing EKS cluster name.
2. In `remediation-bot/lambda.tf`, review `NAMESPACE`, `TARGET_DEPLOYMENT`, `MODEL_ID`, and `COOLDOWN_SECONDS` for your environment. Defaults target `multitier-demo/adminer`, use `eu.amazon.nova-micro-v1:0`, and enforce a 900-second cooldown.
3. Ensure the Lambda execution role is authorized for the required EKS access and Bedrock invocation, and that the SNS alert contains the expected message attributes: `status`, `alertname`, `namespace`, and `deployment`.

### Deploy

```bash
cd remediation-bot
terraform init
terraform validate
terraform plan
terraform apply
```

Review the plan and confirm that the backend, cluster, IAM access, alert source, and target workload are correct before applying.
