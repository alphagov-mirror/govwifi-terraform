provider "aws" {
  # Workaround for import issue, see https://github.com/hashicorp/terraform/issues/13018#issuecomment-291547317
  version = "2.10.0"
  alias   = "AWS-main"
  region  = "${var.aws-region}"
}

provider "aws" {
  version = "2.10.0"
  alias   = "route53-alarms"
  region  = "us-east-1"
}

module "tfstate" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source             = "../../terraform-state"
  product-name       = "${var.product-name}"
  Env-Name           = "${var.Env-Name}"
  aws-account-id     = "${var.aws-account-id}"
  aws-region         = "${var.aws-region}"
  aws-region-name    = "${var.aws-region-name}"
  backup-region-name = "${var.backup-region-name}"

  # TODO: separate module for accesslogs
  accesslogs-glacier-transition-days = 30
  accesslogs-expiration-days         = 90
}

terraform {
  backend "s3" {
    # Interpolation is not allowed here.
    #bucket = "${lower(var.product-name)}-${lower(var.Env-Name)}-${lower(var.aws-region-name)}-tfstate"
    #key    = "${lower(var.aws-region-name)}-tfstate"
    #region = "${var.aws-region}"
    bucket = "govwifi-wifi-dublin-tfstate"

    key    = "dublin-tfstate"
    region = "eu-west-1"
  }
}

module "govwifi-keys" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source = "../../govwifi-keys"
}

# Backend =====================================================================
module "backend" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source        = "../../govwifi-backend"
  env           = "production"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  # AWS VPC setup -----------------------------------------
  aws-region      = "${var.aws-region}"
  aws-region-name = "${var.aws-region-name}"
  route53-zone-id = "${var.route53-zone-id}"
  vpc-cidr-block  = "10.42.0.0/16"
  zone-count      = "${var.zone-count}"
  zone-names      = "${var.zone-names}"

  zone-subnets = {
    zone0 = "10.42.1.0/24"
    zone1 = "10.42.2.0/24"
    zone2 = "10.42.3.0/24"
  }

  backend-subnet-IPs  = "${var.backend-subnet-IPs}"
  administrator-IPs   = "${var.administrator-IPs}"
  bastion-server-IP   = "${var.bastion-server-IP}"
  frontend-radius-IPs = "${var.frontend-radius-IPs}"

  # Instance-specific setup -------------------------------
  # eu-west-1, CIS Ubuntu Linux 16.04 LTS Benchmark v1.0.0.4 - Level 1
  bastion-ami = "ami-51d3e928"

  bastion-instance-type     = "t2.micro"
  bastion-server-ip         = "${var.bastion-server-IP}"
  bastion-ssh-key-name      = "govwifi-bastion-key-20181025"
  enable-bastion-monitoring = true
  users                     = "${var.users}"
  aws-account-id            = "${var.aws-account-id}"

  db-instance-count        = 0
  session-db-instance-type = "db.m4.xlarge"
  session-db-storage-gb    = 1000
  db-backup-retention-days = 7
  db-encrypt-at-rest       = true
  db-maintenance-window    = "wed:01:42-wed:02:12"
  db-backup-window         = "04:42-05:42"

  db-replica-count      = 0
  user-db-replica-count = 1
  rr-instance-type      = "db.m3.medium"
  rr-storage-gb         = 1000

  critical-notifications-arn = "${module.critical-notifications.topic-arn}"
  capacity-notifications-arn = "${module.capacity-notifications.topic-arn}"
  user-replica-source-db     = "arn:aws:rds:eu-west-2:${var.aws-account-id}:db:wifi-production-user-db"

  # Seconds. Set to zero to disable monitoring
  db-monitoring-interval = 60

  # Passed to application
  db-user               = "${var.db-user}"
  db-password           = "${var.db-password}"
  user-db-password      = "${var.user-db-password}"
  user-db-username      = "${var.user-db-username}"
  user-db-instance-type = "db.t2.medium"
  user-db-hostname      = "${var.user-db-hostname}"
  user-db-storage-gb    = 20
  user-rr-hostname      = "${var.user-rr-hostname}"
}

# Emails ======================================================================
module "emails" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source                   = "../../govwifi-emails"
  product-name             = "${var.product-name}"
  Env-Name                 = "${var.Env-Name}"
  Env-Subdomain            = "${var.Env-Subdomain}"
  aws-account-id           = "${var.aws-account-id}"
  route53-zone-id          = "${var.route53-zone-id}"
  aws-region               = "${var.aws-region}"
  aws-region-name          = "${var.aws-region-name}"
  mail-exchange-server     = "10 inbound-smtp.eu-west-1.amazonaws.com"
  devops-notifications-arn = "${module.devops-notifications.topic-arn}"

  #sns-endpoint             = "https://elb.${lower(var.aws-region-name)}.${var.Env-Subdomain}.service.gov.uk/sns/"
  sns-endpoint                       = "https://elb.london.${var.Env-Subdomain}.service.gov.uk/sns/"
  user-signup-notifications-endpoint = "https://user-signup-api.${var.Env-Subdomain}.service.gov.uk:8443/user-signup/email-notification"
}

# Global ====================================================================
module "account" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source     = "../../govwifi-account"
  account-id = "${var.aws-parent-account-id}"
}

module "dns" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source             = "../../global-dns"
  Env-Name           = "${var.Env-Name}"
  Env-Subdomain      = "${var.Env-Subdomain}"
  route53-zone-id    = "${var.route53-zone-id}"
  status-page-domain = "govwifi.hund.io"
}

# Frontend ====================================================================
module "frontend" {
  providers = {
    "aws"                = "aws.AWS-main"
    "aws.route53-alarms" = "aws.route53-alarms"
  }

  source        = "../../govwifi-frontend"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  # AWS VPC setup -----------------------------------------
  aws-region      = "${var.aws-region}"
  aws-region-name = "${var.aws-region-name}"
  route53-zone-id = "${var.route53-zone-id}"
  vpc-cidr-block  = "10.43.0.0/16"
  zone-count      = "${var.zone-count}"
  zone-names      = "${var.zone-names}"
  rack-env        = "production"

  zone-subnets = {
    zone0 = "10.43.1.0/24"
    zone1 = "10.43.2.0/24"
    zone2 = "10.43.3.0/24"
  }

  # Instance-specific setup -------------------------------
  radius-instance-count      = 3
  enable-detailed-monitoring = true

  # eg. dns records are generated for radius(N).x.service.gov.uk
  # where N = this base + 1 + server#
  dns-numbering-base = 0

  elastic-ip-list       = ["${split(",", var.frontend-region-IPs)}"]
  ami                   = "${var.ami}"
  ssh-key-name          = "${var.ssh-key-name}"
  users                 = "${var.users}"
  frontend-docker-image = "${format("%s/frontend:production", var.docker-image-path)}"
  raddb-docker-image    = "${format("%s/raddb:production", var.docker-image-path)}"

  shared-key = "${var.shared-key}"

  # admin bucket
  admin-bucket-name = "govwifi-production-admin"

  logging-api-base-url = "${var.london-api-base-url}"
  auth-api-base-url    = "${var.dublin-api-base-url}"

  # A site with this radkey must exist in the database for health checks to work
  healthcheck-radius-key = "${var.hc-key}"
  healthcheck-ssid       = "${var.hc-ssid}"
  healthcheck-identity   = "${var.hc-identity}"
  healthcheck-password   = "${var.hc-password}"

  route53-critical-notifications-arn = "${module.route53-critical-notifications.topic-arn}"
  devops-notifications-arn           = "${module.devops-notifications.topic-arn}"

  # Security groups ---------------------------------------
  radius-instance-sg-ids = []

  bastion-ips = [
    "${split(",", var.bastion-server-IP)}",
    "${split(",", var.backend-subnet-IPs)}",
  ]
}

module "api" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  env           = "production"
  source        = "../../govwifi-api"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  ami                     = "${var.ami}"
  ssh-key-name            = "${var.ssh-key-name}"
  users                   = "${var.users}"
  backend-elb-count       = 1
  backend-instance-count  = 2
  authorisation-api-count = 3
  backend-min-size        = 1
  backend-cpualarm-count  = 1
  aws-account-id          = "${var.aws-account-id}"
  aws-region-name         = "${lower(var.aws-region-name)}"
  aws-region              = "${var.aws-region}"
  route53-zone-id         = "${var.route53-zone-id}"
  vpc-id                  = "${module.backend.backend-vpc-id}"

  user-signup-enabled  = 0
  logging-enabled      = 0
  alarm-count          = 0
  safe-restart-enabled = 0
  event-rule-count     = 0

  critical-notifications-arn = "${module.critical-notifications.topic-arn}"
  capacity-notifications-arn = "${module.capacity-notifications.topic-arn}"
  devops-notifications-arn   = "${module.devops-notifications.topic-arn}"

  auth-docker-image         = "${format("%s/authorisation-api:production", var.docker-image-path)}"
  logging-docker-image      = "${format("%s/logging-api:production", var.docker-image-path)}"
  safe-restart-docker-image = "${format("%s/safe-restarter:production", var.docker-image-path)}"

  db-user                   = "${var.db-user}"
  db-password               = "${var.db-password}"
  db-hostname               = "db.${lower(var.aws-region-name)}.${var.Env-Subdomain}.service.gov.uk"
  db-read-replica-hostname  = "rr.${lower(var.aws-region-name)}.${var.Env-Subdomain}.service.gov.uk"
  rack-env                  = "production"
  radius-server-ips         = "${split(",", var.frontend-radius-IPs)}"
  authentication-sentry-dsn = "${var.auth-sentry-dsn}"
  safe-restart-sentry-dsn   = "${var.safe-restart-sentry-dsn}"
  shared-key                = "${var.shared-key}"
  user-signup-docker-image  = ""
  logging-sentry-dsn        = ""
  user-signup-sentry-dsn    = ""
  subnet-ids                = "${module.backend.backend-subnet-ids}"
  ecs-instance-profile-id   = "${module.backend.ecs-instance-profile-id}"
  ecs-service-role          = "${module.backend.ecs-service-role}"
  user-signup-api-base-url  = ""
  user-db-username          = "${var.user-db-username}"
  user-db-hostname          = "${var.user-db-hostname}"
  user-db-password          = "${var.user-db-password}"
  user-rr-hostname          = "${var.user-rr-hostname}"
  background-jobs-enabled   = 0

  elb-sg-list = []

  backend-sg-list = [
    "${module.backend.be-admin-in}",
  ]
}

module "critical-notifications" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source = "../../sns-notification"

  env-name   = "${var.Env-Name}"
  topic-name = "govwifi-wifi-critical"
  emails     = ["${var.critical-notification-email}"]
}

module "capacity-notifications" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source = "../../sns-notification"

  env-name   = "${var.Env-Name}"
  topic-name = "govwifi-wifi-capacity"
  emails     = ["${var.capacity-notification-email}"]
}

module "devops-notifications" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source = "../../sns-notification"

  env-name   = "${var.Env-Name}"
  topic-name = "govwifi-wifi-devops"
  emails     = ["${var.devops-notification-email}"]
}

module "route53-critical-notifications" {
  providers = {
    "aws" = "aws.route53-alarms"
  }

  source = "../../sns-notification"

  env-name   = "${var.Env-Name}"
  topic-name = "govwifi-wifi-critical"
  emails     = ["${var.critical-notification-email}"]
}
