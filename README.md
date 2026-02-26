# Resilient Decoupled Order Processor

This project implements the architecture in `NOTES.md`:
- SQS FIFO queue for ordered, deduplicated order intake
- DynamoDB table keyed by `OrderID`
- Spot-only EC2 Auto Scaling Group in private subnets
- Route 53 failover record with an S3 static standby page
- Ansible bootstrapping to install and run a Python worker

## Layout
- `terraform/`: infrastructure
- `ansible/worker.yml`: worker host configuration
- `app/worker.py`: long-running SQS -> DynamoDB processor
- `scripts/send_orders.sh`: enqueue 100 test orders quickly

## Deploy
1. Configure AWS credentials and region.
2. Fill `terraform/terraform.tfvars` from `terraform/terraform.tfvars.example`.
3. Run:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

## Test
After apply:
```bash
QUEUE_URL=$(terraform -chdir=terraform output -raw queue_url)
./scripts/send_orders.sh "$QUEUE_URL" 100
```

The worker stores each order once via a conditional DynamoDB write, preserving FIFO order through a single message group.
