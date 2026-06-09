# ──────────────────────────────────────────────────────────────────────────────
# DMS (Database Migration Service)
#
# Phase 1 (enable_migration=true): IDC MySQL EC2 → Aurora MySQL — Full Load
# Phase 2 (상시):                  Aurora MySQL  → Azure MySQL  — CDC (DR 동기화)
#
# DMS 인스턴스·서브넷그룹은 Phase 2 CDC가 상시 필요하므로 count 없이 항상 생성
# SG는 security_groups.tf의 aws_security_group.dms 참조
# ──────────────────────────────────────────────────────────────────────────────

# ── 공통 인프라 (항상 생성) ──────────────────────────────────────────────────────

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "threetier-dms-subnet-group"
  replication_subnet_group_description = "DMS Replication Subnet Group for ThreeTier VPC"
  subnet_ids = [
    aws_subnet.private_backend.id,
    aws_subnet.private_backend_2.id
  ]
  tags = { Name = "ThreeTier-DMS-SubnetGroup" }
}

resource "aws_dms_replication_instance" "main" {
  replication_instance_id     = "dms-truck"
  replication_instance_class  = "dms.t3.small"
  engine_version              = "3.5.4"
  allocated_storage           = 50
  multi_az                    = false
  publicly_accessible         = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  tags = { Name = "ThreeTier-DMS-ReplicationInstance" }
}

# ── Phase 1: IDC MySQL EC2 → Aurora MySQL (Full Load, enable_migration 제어) ──

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
  engine_name   = "mariadb"
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
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target[0].endpoint_arn
  migration_type           = "full-load"
  start_replication_task   = false

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

# ── Phase 2: Aurora MySQL → Azure MySQL Flexible Server (CDC, DR 동기화) ────────

locals {
  cdc_enabled = var.azure_mysql_host != "" && var.azure_mysql_password != ""
}

# Aurora 소스 엔드포인트 — binlog CDC 활성화 전제 (rds.tf의 cdc 파라미터 그룹 + 재부팅 필요)
resource "aws_dms_endpoint" "aurora_source" {
  count         = local.cdc_enabled ? 1 : 0
  endpoint_id   = "cdc-source-aurora"
  endpoint_type = "source"
  engine_name   = "aurora"
  server_name   = aws_rds_cluster.main.endpoint
  port          = 3306
  username      = "dms_replicator"
  password      = var.db_password
  ssl_mode      = "none"

  tags = { Name = "ThreeTier-CDC-Source-Aurora" }
}

# Azure MySQL 타깃 엔드포인트 — VPN 경유 프라이빗 IP 접속
resource "aws_dms_endpoint" "azure_target" {
  count         = local.cdc_enabled ? 1 : 0
  endpoint_id   = "cdc-target-azure-mysql"
  endpoint_type = "target"
  engine_name   = "mysql"
  server_name   = var.azure_mysql_host
  port          = 3306
  username      = var.azure_mysql_user
  password      = var.azure_mysql_password
  ssl_mode      = "none"

  tags = { Name = "ThreeTier-CDC-Target-Azure" }
}

# CDC 복제 태스크 — Aurora(source) → Azure MySQL(target), RPO ~5분
resource "aws_dms_replication_task" "aurora_to_azure" {
  count                    = local.cdc_enabled ? 1 : 0
  replication_task_id      = "cdc-aurora-to-azure"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.aurora_source[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.azure_target[0].endpoint_arn
  migration_type           = "cdc"
  start_replication_task   = false

  table_mappings = jsonencode({
    rules = [
      { rule-type = "selection", rule-id = "1", rule-name = "cdc-auth",    object-locator = { schema-name = "auth_db",    table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "2", rule-name = "cdc-hotel",   object-locator = { schema-name = "hotel_db",   table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "3", rule-name = "cdc-booking", object-locator = { schema-name = "booking_db", table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "4", rule-name = "cdc-review",  object-locator = { schema-name = "review_db",  table-name = "%" }, rule-action = "include" },
      { rule-type = "selection", rule-id = "5", rule-name = "cdc-support", object-locator = { schema-name = "support_db", table-name = "%" }, rule-action = "include" }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = { TargetSchema = "", SupportLobs = true, FullLobMode = false, LobChunkSize = 64, LimitedSizeLobMode = true, LobMaxSize = 32 }
    FullLoadSettings = { TargetTablePrepMode = "DO_NOTHING" }
    Logging = { EnableLogging = true, LogComponents = [
      { Id = "SOURCE_CAPTURE", Severity = "LOGGER_SEVERITY_DEFAULT" },
      { Id = "TARGET_APPLY",   Severity = "LOGGER_SEVERITY_DEFAULT" },
      { Id = "TASK_MANAGER",   Severity = "LOGGER_SEVERITY_DEFAULT" }
    ]}
  })

  tags = { Name = "ThreeTier-CDC-Aurora-to-Azure" }
}
