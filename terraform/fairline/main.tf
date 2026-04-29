resource "random_password" "db_master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_master" {
  count                   = var.create_secrets_manager_secret ? 1 : 0
  name                    = "${local.base_name}/rds/master"
  description             = "Master credentials for the Fairline PostgreSQL RDS instance."
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_master" {
  count     = var.create_secrets_manager_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_master[0].id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
    username = var.db_master_username
    password = random_password.db_master.result
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.base_name}-rds-sg"
  description = "Allow PostgreSQL access from the team4 EKS worker nodes."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.base_name}-rds-sg" }
  )
}

resource "aws_db_parameter_group" "postgres" {
  count       = var.create_db_parameter_group ? 1 : 0
  name        = "${local.base_name}-postgres"
  family      = var.db_parameter_group_family
  description = "PostgreSQL parameter group with logical replication enabled for CDC."

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "max_replication_slots"
    value        = tostring(var.logical_replication_max_slots)
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "max_wal_senders"
    value        = tostring(var.logical_replication_max_senders)
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "max_logical_replication_workers"
    value        = tostring(var.logical_replication_max_workers)
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.base_name}-postgres" }
  )
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${local.base_name}-postgres"
  engine                     = "postgres"
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = var.db_name
  username                   = var.db_master_username
  password                   = random_password.db_master.result
  port                       = 5432
  multi_az                   = var.db_multi_az
  publicly_accessible        = var.db_publicly_accessible
  backup_retention_period    = var.db_backup_retention_period
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
  apply_immediately          = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  db_subnet_group_name   = var.db_subnet_group_name
  parameter_group_name   = var.create_db_parameter_group ? aws_db_parameter_group.postgres[0].name : null
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = merge(
    local.common_tags,
    { Name = "${local.base_name}-postgres" }
  )
}
