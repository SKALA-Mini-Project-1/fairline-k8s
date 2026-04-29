variable "aws_region" {
  description = "AWS region for Fairline infrastructure."
  type        = string
  default     = "ap-northeast-2"
}

variable "name_prefix" {
  description = "Prefix applied to AWS resource names."
  type        = string
  default     = "fairline"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where EKS nodes and RDS should live."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Existing DB subnet group name to reuse in the shared AWS account."
  type        = string
  default     = "eks-vpc-shared-rds-subnets"
}

variable "eks_node_security_group_id" {
  description = "Security group attached to the EKS worker nodes that need DB access."
  type        = string
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "concert"
}

variable "db_master_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "fairline_admin"
}

variable "create_secrets_manager_secret" {
  description = "Create a Secrets Manager secret for the generated master credentials."
  type        = bool
  default     = false
}

variable "create_db_parameter_group" {
  description = "Create a dedicated PostgreSQL parameter group with logical replication enabled."
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled storage in GiB."
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "PostgreSQL engine version. Keep this aligned with the parameter group family."
  type        = string
  default     = "16.13"
}

variable "db_parameter_group_family" {
  description = "Parameter group family that matches the engine major version."
  type        = string
  default     = "postgres16"
}

variable "db_backup_retention_period" {
  description = "Retention period for automated backups."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment."
  type        = bool
  default     = false
}

variable "db_publicly_accessible" {
  description = "Whether the DB instance gets a public endpoint."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protect the DB from accidental deletion."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy."
  type        = bool
  default     = true
}

variable "logical_replication_max_slots" {
  description = "Value for max_replication_slots."
  type        = number
  default     = 10
}

variable "logical_replication_max_senders" {
  description = "Value for max_wal_senders."
  type        = number
  default     = 10
}

variable "logical_replication_max_workers" {
  description = "Value for max_logical_replication_workers."
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
