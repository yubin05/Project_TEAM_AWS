# ──────────────────────────────────────────────────────────────────────────────
# DMS (Database Migration Service)
# MySQL EC2 (소스) → Aurora MySQL (타깃) Full Load 마이그레이션
#
# enable_migration = true  → MySQL EC2 + DMS 리소스 전체 생성
# enable_migration = false → terraform apply 시 전체 자동 삭제
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "dms" {
  count       = var.enable_migration ? 1 : 0
  name        = "ThreeTier-DMS-SG"
  description = "DMS Replication Instance Security Group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ThreeTier-DMS-SG" }

  # destroy 순서 보장: mysql/rds SG에서 이 SG를 참조하는 ingress 규칙이
  # 먼저 제거된 후 이 SG가 삭제되도록 역방향 의존성 설정
  depends_on = [aws_security_group.mysql, aws_security_group.rds]
}


resource "aws_dms_replication_subnet_group" "main" {
  count                                = var.enable_migration ? 1 : 0
  replication_subnet_group_id          = "threetier-dms-subnet-group"
  replication_subnet_group_description = "DMS Replication Subnet Group for ThreeTier VPC"
  subnet_ids = [
    aws_subnet.private_backend.id,
    aws_subnet.private_backend_2.id
  ]
  tags = { Name = "ThreeTier-DMS-SubnetGroup" }
}

resource "aws_dms_replication_instance" "main" {
  count                       = var.enable_migration ? 1 : 0
  replication_instance_id     = "dms-truck"
  replication_instance_class  = "dms.t3.small"
  engine_version              = "3.5.4"
  allocated_storage           = 50
  multi_az                    = false
  publicly_accessible         = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main[0].id
  vpc_security_group_ids      = [aws_security_group.dms[0].id]

  tags = { Name = "ThreeTier-DMS-ReplicationInstance" }
}

resource "null_resource" "wait_for_mysql" {
  count = var.enable_migration ? 1 : 0

  provisioner "local-exec" {
    command = <<-SH
      echo "MySQL EC2 준비 대기 중..."
      for i in $(seq 1 30); do
        RESULT=$(aws ssm send-command \
          --instance-id ${aws_instance.mysql[0].id} \
          --document-name "AWS-RunShellScript" \
          --parameters 'commands=["test -f /tmp/mysql_ready && echo READY || echo NOT_READY"]' \
          --query "Command.CommandId" --output text \
          --region ${var.aws_region} --profile ${var.aws_profile} 2>/dev/null)
        sleep 5
        STATUS=$(aws ssm get-command-invocation \
          --command-id "$RESULT" \
          --instance-id ${aws_instance.mysql[0].id} \
          --query "StandardOutputContent" --output text \
          --region ${var.aws_region} --profile ${var.aws_profile} 2>/dev/null || echo "")
        if echo "$STATUS" | grep -q "READY"; then
          echo "MySQL 준비 완료"
          exit 0
        fi
        echo "[$i/30] 아직 준비 중... 20초 후 재시도"
        sleep 20
      done
      echo "타임아웃: MySQL 준비 확인 실패"
      exit 1
    SH
  }

  depends_on = [aws_instance.mysql]
}

resource "aws_dms_endpoint" "source" {
  count         = var.enable_migration ? 1 : 0
  endpoint_id   = "source-mysql-ec2"
  endpoint_type = "source"
  engine_name   = "mysql"
  server_name   = aws_instance.mysql[0].private_ip
  depends_on    = [null_resource.wait_for_mysql]
  port          = 3306
  username      = "root"
  password      = var.db_password
  database_name = ""

  tags = { Name = "ThreeTier-DMS-Source" }
}

resource "aws_dms_endpoint" "target" {
  count         = var.enable_migration ? 1 : 0
  endpoint_id   = "target-aurora-mysql"
  endpoint_type = "target"
  engine_name   = "aurora"
  server_name   = aws_rds_cluster.main.endpoint
  port          = 3306
  username      = "admin"
  password      = var.db_password
  database_name = ""

  tags = { Name = "ThreeTier-DMS-Target" }
}

resource "aws_dms_replication_task" "full_load" {
  count                    = var.enable_migration ? 1 : 0
  replication_task_id      = "my-migration-task"
  replication_instance_arn = aws_dms_replication_instance.main[0].replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target[0].endpoint_arn
  migration_type           = "full-load"
  start_replication_task   = true

  table_mappings = jsonencode({
    rules = [
      { rule-type = "selection", rule-id = "1", rule-name = "include-auth",    object-locator = { schema-name = "auth_db",    table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "2", rule-name = "include-hotel",   object-locator = { schema-name = "hotel_db",   table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "3", rule-name = "include-booking", object-locator = { schema-name = "booking_db", table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "4", rule-name = "include-review",  object-locator = { schema-name = "review_db",  table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "5", rule-name = "include-support", object-locator = { schema-name = "support_db", table-name = "%" }, rule-action = "include" }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = { TargetSchema = "", SupportLobs = true, FullLobMode = false, LobChunkSize = 64, LimitedSizeLobMode = true, LobMaxSize = 32 }
    FullLoadSettings = { TargetTablePrepMode = "TRUNCATE_BEFORE_LOAD", CreatePkAfterFullLoad = false, StopTaskCachedChangesApplied = false, StopTaskCachedChangesNotApplied = false, MaxFullLoadSubTasks = 8, TransactionConsistencyTimeout = 600, CommitRate = 50000 }
    Logging = { EnableLogging = true, LogComponents = [{ Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DEFAULT" }, { Id = "TARGET_LOAD", Severity = "LOGGER_SEVERITY_DEFAULT" }, { Id = "TASK_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" }] }
  })

  tags = { Name = "ThreeTier-DMS-MigrationTask" }
}
