output "rds_endpoint" {
  description = "DNS endpoint for the PostgreSQL instance."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.postgres.port
}

output "rds_db_name" {
  description = "Initial database name."
  value       = aws_db_instance.postgres.db_name
}

output "rds_jdbc_url" {
  description = "JDBC URL that can be pasted into the current k8s ConfigMap."
  value       = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
}

output "rds_security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = aws_security_group.rds.id
}

output "rds_master_secret_arn" {
  description = "Secrets Manager ARN containing the master credentials."
  value       = var.create_secrets_manager_secret ? aws_secretsmanager_secret.db_master[0].arn : null
}

output "rds_parameter_group_name" {
  description = "DB parameter group with logical replication enabled."
  value       = var.create_db_parameter_group ? aws_db_parameter_group.postgres[0].name : null
}

output "rds_master_username" {
  description = "Master username for the PostgreSQL instance."
  value       = var.db_master_username
}

output "rds_master_password" {
  description = "Generated master password for the PostgreSQL instance."
  value       = random_password.db_master.result
  sensitive   = true
}
