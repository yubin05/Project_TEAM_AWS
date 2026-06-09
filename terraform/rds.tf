
# DMS CDC 소스 요구사항: binlog_format=ROW, binlog_checksum=NONE
resource "aws_rds_cluster_parameter_group" "cdc" {
  name        = "threetier-aurora-cdc"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL parameter group for DMS CDC replication"

  parameter {
    name         = "binlog_format"
    value        = "ROW"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "binlog_checksum"
    value        = "NONE"
    apply_method = "pending-reboot"
  }

  tags = { Name = "ThreeTier-Aurora-CDC-ParamGroup" }
}

resource "aws_db_subnet_group" "main" {
  name       = "threetier-db-subnet-group"
  subnet_ids = [aws_subnet.private_db.id, aws_subnet.private_db_2.id]
  tags       = { Name = "ThreeTier-DB-Subnet-Group" }
}

# ── Aurora MySQL 클러스터 ─────────────────────────────────────────────────────
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "threetier-aurora-cluster"
  engine                          = "aurora-mysql"
  engine_version                  = "8.0.mysql_aurora.3.04.0"
  database_name                   = "main_db"
  master_username                 = "admin"
  master_password                 = var.db_password
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.cdc.name
  skip_final_snapshot             = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = { Name = "ThreeTier-Aurora-Cluster" }
}

# ── Writer 인스턴스 ───────────────────────────────────────────────────────────
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "threetier-aurora-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  tags               = { Name = "ThreeTier-Aurora-Writer" }
}

# ── Reader 인스턴스 (읽기 분산) ───────────────────────────────────────────────
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "threetier-aurora-reader"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  tags               = { Name = "ThreeTier-Aurora-Reader" }
}

# ── Reader Auto Scaling (성수기 트래픽 급증 대응) ─────────────────────────────
resource "aws_appautoscaling_target" "aurora_reader" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "cluster:${aws_rds_cluster.main.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"
  depends_on         = [aws_rds_cluster_instance.reader]
}

resource "aws_appautoscaling_policy" "aurora_reader" {
  name               = "threetier-aurora-reader-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.aurora_reader.resource_id
  scalable_dimension = aws_appautoscaling_target.aurora_reader.scalable_dimension
  service_namespace  = aws_appautoscaling_target.aurora_reader.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
