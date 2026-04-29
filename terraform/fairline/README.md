# Fairline AWS Database Bootstrap

This Terraform stack creates the first AWS building blocks needed for CDC and Outbox:

- A PostgreSQL RDS instance inside the same VPC as the EKS worker nodes
- Reuse of the shared DB subnet group that already exists in the account
- A dedicated security group that only allows PostgreSQL from the EKS node security group
- A PostgreSQL parameter group with logical replication enabled for Debezium CDC
- Optional Secrets Manager storage for the generated master credentials

## Files

- `main.tf`: RDS, security group, parameter group, optional secret
- `variables.tf`: inputs for VPC, subnets, sizing, and PostgreSQL settings
- `outputs.tf`: endpoint, JDBC URL, and secret ARN for teammates
- `terraform.tfvars.example`: starter values for the current team4 EKS network

## Quick Start

1. Copy the example variable file.
2. Review the sizing and deletion settings.
3. Run Terraform.

```bash
cd terraform/fairline
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## After Apply

Use the Terraform outputs to wire the apps to RDS:

```bash
terraform output rds_endpoint
terraform output rds_jdbc_url
terraform output rds_master_secret_arn
```

Fetch the generated master credentials from Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --region ap-northeast-2 \
  --secret-id "$(terraform output -raw rds_master_secret_arn)"
```

If `create_secrets_manager_secret = false`, read the generated password from Terraform instead:

```bash
terraform output -raw rds_master_username
terraform output -raw rds_master_password
```

Then update the current Kubernetes values:

- `configmap.yaml`: replace `DB_URL` with the RDS JDBC URL
- `secret.yaml`: replace `DB_USER` and `DB_PASSWORD` with the RDS credentials
- `infra/postgres/`: remove this deployment after all services have switched to RDS

## Why This Is CDC-Ready

The parameter group enables the RDS settings Debezium needs for logical replication:

- `rds.logical_replication = 1`
- `max_replication_slots`
- `max_wal_senders`
- `max_logical_replication_workers`

This is the minimum DB-side groundwork for the next step:

1. create service-owned schemas and tables
2. add `outbox_event` tables in the application services
3. provision Kafka and Debezium connectors
4. create publications and replication slots for CDC

## Notes

- The example reuses the existing shared subnet group `eks-vpc-shared-rds-subnets`.
- The example creates a new RDS-only security group and allows access from the current team4 EKS node security group `sg-06abf01dd54907a21`.
- The example was verified against `ap-northeast-2` availability on 2026-04-29 and uses `PostgreSQL 16.13` with the `postgres16` parameter group family.
- The default instance class is intentionally small for fast bring-up. Increase it before load testing.
- `db_deletion_protection = false` and `db_skip_final_snapshot = true` are convenient for a dev environment but are risky for production.
