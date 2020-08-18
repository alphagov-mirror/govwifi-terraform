variable "Env-Name" {}

variable "env" {}

variable "Env-Subdomain" {}

variable "route53-zone-id" {}

variable "vpc-cidr-block" {}

variable "aws-account-id" {}

variable "aws-region" {}

variable "aws-region-name" {}

variable "backend-subnet-IPs" {}
variable "administrator-IPs" {}
variable "bastion-server-IP" {}
variable "frontend-radius-IPs" {}

variable "zone-count" {}

variable "zone-names" {
  type = "map"
}

variable "zone-subnets" {
  type = "map"
}

variable "enable-bastion" {
  default = true
}

variable "bastion-ami" {}

variable "bastion-instance-type" {}

variable "bastion-server-ip" {}

variable "bastion-ssh-key-name" {}

variable "db-user" {}

variable "db-password" {}

variable "user-db-username" {}

variable "user-db-password" {}

variable "user-db-hostname" {}

variable "user-rr-hostname" {}

variable "db-instance-count" {}

variable "db-replica-count" {}

variable "user-db-replica-count" {
  default = 0
}

variable "db-backup-retention-days" {}

variable "db-encrypt-at-rest" {}

variable "session-db-instance-type" {}

variable "user-db-instance-type" {}

variable "db-monitoring-interval" {}

variable "session-db-storage-gb" {}

variable "user-db-storage-gb" {}

variable "db-maintenance-window" {}

variable "db-backup-window" {}

variable "rr-instance-type" {}

variable "rr-storage-gb" {}

variable "user-rr-instance-type" {
  default = "db.t2.medium"
}

variable "user-rr-storage-gb" {
  default = 20
}

variable "critical-notifications-arn" {}

variable "capacity-notifications-arn" {}

variable "enable-bastion-monitoring" {}

variable "users" {
  type = "list"
}

variable "save-pp-data" {
  description = "Whether or not to save Performance Platform backup data. Value must be 0 or 1."
  default     = "0"
}

variable "pp-domain-name" {
  default = ""
}

variable "user-replica-source-db" {
  type    = "string"
  default = ""
}

variable "rds-kms-key-id" {
  description = "The KMS key necessary to encrypt the replica database"
  type        = "string"
  default = ""
}
