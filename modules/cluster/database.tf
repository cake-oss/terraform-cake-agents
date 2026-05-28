resource "aws_db_subnet_group" "cake_agents" {
  name       = "${var.name}-cake-agents"
  subnet_ids = local.private_subnet_ids
}

resource "aws_security_group" "cake_agents_db" {
  name        = "${var.name}-cake-agents-db"
  description = "Postgres ingress from the ${var.name} VPC for cake-agents"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
    description = "Postgres from cluster VPC"
  }
}

# Per-cluster CMK for RDS storage encryption.
resource "aws_kms_key" "rds" {
  description             = "RDS storage encryption key for the ${var.name} cluster"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootIAM"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds/${var.name}"
  target_key_id = aws_kms_key.rds.key_id
}

module "cake_agents_db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.name}-cake-agents"

  engine               = "postgres"
  engine_version       = "17"
  family               = "postgres17"
  major_engine_version = "17"

  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  db_name  = "cake_agents"
  username = "cake_agents"
  password = random_password.cake_agents_db.result
  port     = 5432

  manage_master_user_password = false

  multi_az               = var.database_multi_az
  db_subnet_group_name   = aws_db_subnet_group.cake_agents.name
  vpc_security_group_ids = [aws_security_group.cake_agents_db.id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 7

  skip_final_snapshot = !var.database_final_snapshot
  deletion_protection = var.database_deletion_protection

  create_cloudwatch_log_group     = false
  performance_insights_enabled    = false
  enabled_cloudwatch_logs_exports = []
}
