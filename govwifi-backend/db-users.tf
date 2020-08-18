resource "aws_db_instance" "users_db" {
  count                       = "${var.db-instance-count}"
  allocated_storage           = "${var.user-db-storage-gb}"
  storage_type                = "gp2"
  engine                      = "mysql"
  engine_version              = "8.0"
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = true
  instance_class              = "${var.user-db-instance-type}"
  identifier                  = "wifi-${var.env}-user-db" // var.env is set to 'staging' at the moment. should it be `staging-temp`?
  // the below line is needed to support environments with hyphens in the name
  name                        = "${replace(format("%s%s%s", "govwifi_", var.env, "_users"), "-", "_")}"
  username                    = "${var.user-db-username}"
  password                    = "${var.user-db-password}"
  backup_retention_period     = "${var.db-backup-retention-days}"
  multi_az                    = true
  storage_encrypted           = "${var.db-encrypt-at-rest}"
  db_subnet_group_name        = "wifi-${var.Env-Name}-subnets"
  vpc_security_group_ids      = ["${aws_security_group.be-db-in.id}"]
  depends_on                  = ["aws_iam_role.rds-monitoring-role"]
  monitoring_role_arn         = "${aws_iam_role.rds-monitoring-role.arn}"
  monitoring_interval         = "${var.db-monitoring-interval}"
  maintenance_window          = "${var.db-maintenance-window}"
  backup_window               = "${var.db-backup-window}"
  skip_final_snapshot         = true
  deletion_protection         = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  option_group_name               = "${aws_db_option_group.user-mariadb-audit.name}"
  parameter_group_name            = "${aws_db_parameter_group.user-db-parameters.name}"

  tags = {
    Name = "${title(var.env)} Users DB"
  }
}

resource "aws_db_instance" "users_read_replica" {
  count                       = "${var.user-db-replica-count}"
  replicate_source_db         = "${var.user-replica-source-db}"
  storage_encrypted           = "${var.db-encrypt-at-rest}"
  storage_type                = "gp2"
  engine_version              = "8.0"
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = true
  instance_class              = "${var.user-rr-instance-type}"
  identifier                  = "wifi-${var.env}-user-rr"
  username                    = "${var.user-db-username}"
  password                    = "${var.user-db-password}"
  backup_retention_period     = 0
  multi_az                    = true
  vpc_security_group_ids      = ["${aws_security_group.be-db-in.id}"]
  monitoring_role_arn         = "${aws_iam_role.rds-monitoring-role.arn}"
  monitoring_interval         = "${var.db-monitoring-interval}"
  maintenance_window          = "${var.db-maintenance-window}"
  backup_window               = "${var.db-backup-window}"
  skip_final_snapshot         = true
  parameter_group_name        = "${aws_db_parameter_group.user-rr-parameters.name}"
  db_subnet_group_name        = "wifi-${var.Env-Name}-subnets"
  deletion_protection         = true

  depends_on = ["aws_db_instance.users_db"]

  tags = {
    Name = "${title(var.Env-Name)} DB Read Replica"
  }
# TODO enable this for Ireland and London
//  kms_key_id = "${var.rds-kms-key-id}"
}
