resource "aws_security_group" "rds" {
  name        = "ThreeTier-RDS-SG"
  description = "Aurora MySQL Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-RDS-SG" }

  ingress {
    # 10.1.3.0/24: MySQL EC2(온프레미스 DB)에서 RDS 접근 허용 — DMS 마이그레이션 완료 후 제거
    description = "MySQL from backend and on-premises DB subnet"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24", "10.1.5.0/24", "10.1.3.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "threetier-db-subnet-group"
  subnet_ids = [aws_subnet.private_db.id, aws_subnet.private_db_2.id]
  tags       = { Name = "ThreeTier-DB-Subnet-Group" }
}

# ── Aurora MySQL 클러스터 ─────────────────────────────────────────────────────
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "threetier-aurora-cluster"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.04.0"
  database_name          = "main_db"
  master_username        = "admin"
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

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
