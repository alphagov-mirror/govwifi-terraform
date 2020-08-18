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
    bucket = "govwifi-wifi-london-tfstate"

    key    = "london-tfstate"
    region = "eu-west-2"
  }
}

module "govwifi-keys" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source = "../../govwifi-keys"
}

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
  vpc-cidr-block  = "10.84.0.0/16"
  zone-count      = "${var.zone-count}"
  zone-names      = "${var.zone-names}"

  zone-subnets = {
    zone0 = "10.84.1.0/24"
    zone1 = "10.84.2.0/24"
    zone2 = "10.84.3.0/24"
  }

  # Instance-specific setup -------------------------------

  backend-subnet-IPs  = "${var.backend-subnet-IPs}"
  administrator-IPs   = "${var.administrator-IPs}"
  bastion-server-IP   = "${var.bastion-server-IP}"
  frontend-radius-IPs = "${var.frontend-radius-IPs}"
  # eu-west-2, CIS Ubuntu Linux 16.04 LTS Benchmark v1.0.0.4 - Level 1
  bastion-ami                = "ami-ae6d81c9"
  bastion-instance-type      = "t2.micro"
  bastion-server-ip          = "${var.bastion-server-IP}"
  bastion-ssh-key-name       = "govwifi-bastion-key-20181025"
  enable-bastion-monitoring  = true
  users                      = "${var.users}"
  aws-account-id             = "${var.aws-account-id}"
  db-instance-count          = 1
  session-db-instance-type   = "db.m4.xlarge"
  session-db-storage-gb      = 1000
  db-backup-retention-days   = 7
  db-encrypt-at-rest         = true
  db-maintenance-window      = "wed:01:42-wed:02:12"
  db-backup-window           = "03:05-04:05"
  db-replica-count           = 1
  rr-instance-type           = "db.m4.xlarge"
  rr-storage-gb              = 1000
  critical-notifications-arn = "${module.critical-notifications.topic-arn}"
  capacity-notifications-arn = "${module.capacity-notifications.topic-arn}"
  user-replica-source-db     = "wifi-production-user-db"
  # Seconds. Set to zero to disable monitoring
  db-monitoring-interval = 60
  # Passed to application
  db-user               = "${var.db-user}"
  db-password           = "${var.db-password}"
  user-db-username      = "${var.user-db-username}"
  user-db-password      = "${var.user-db-password}"
  user-db-hostname      = "${var.user-db-hostname}"
  user-rr-hostname      = "${var.user-rr-hostname}"
  user-db-instance-type = "db.t2.medium"
  user-db-storage-gb    = 1000
  user-db-replica-count = 1
  # Whether or not to save Performance Platform backup data
  save-pp-data   = 1
  pp-domain-name = "www.performance.service.gov.uk"
}

# London Frontend ======DIFFERENT AWS REGION===================================
module "frontend" {
  providers = {
    "aws"                = "aws.AWS-main"
    "aws.route53-alarms" = "aws.route53-alarms"
  }

  source        = "../../govwifi-frontend"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  # AWS VPC setup -----------------------------------------
  # LONDON
  aws-region = "${var.aws-region}"

  aws-region-name = "${var.aws-region-name}"
  route53-zone-id = "${var.route53-zone-id}"
  vpc-cidr-block  = "10.85.0.0/16"
  zone-count      = "${var.zone-count}"
  zone-names      = "${var.zone-names}"
  rack-env        = "production"

  zone-subnets = {
    zone0 = "10.85.1.0/24"
    zone1 = "10.85.2.0/24"
    zone2 = "10.85.3.0/24"
  }

  # Instance-specific setup -------------------------------
  radius-instance-count      = 3
  enable-detailed-monitoring = true

  # eg. dns records are generated for radius(N).x.service.gov.uk
  # where N = this base + 1 + server#
  dns-numbering-base = 3

  elastic-ip-list       = ["${split(",", var.frontend-region-IPs)}"]
  ami                   = "${var.ami}"
  ssh-key-name          = "${var.ssh-key-name}"
  users                 = "${var.users}"
  frontend-docker-image = "${format("%s/frontend:production", var.docker-image-path)}"
  raddb-docker-image    = "${format("%s/raddb:production", var.docker-image-path)}"
  shared-key            = "${var.shared-key}"

  # admin bucket
  admin-bucket-name = "govwifi-production-admin"

  logging-api-base-url = "${var.london-api-base-url}"
  auth-api-base-url    = "${var.london-api-base-url}"

  # A site with this radkey must exist in the database for health checks to work
  healthcheck-radius-key = "${var.hc-key}"
  healthcheck-ssid       = "${var.hc-ssid}"
  healthcheck-identity   = "${var.hc-identity}"
  healthcheck-password   = "${var.hc-password}"

  # This must be based on us-east-1, as that's where the alarms go
  route53-critical-notifications-arn = "${module.route53-critical-notifications.topic-arn}"
  devops-notifications-arn           = "${module.devops-notifications.topic-arn}"

  # Security groups ---------------------------------------
  radius-instance-sg-ids = []

  bastion-ips = [
    "${split(",", var.bastion-server-IP)}",
    "${split(",", var.backend-subnet-IPs)}",
  ]
}

module "govwifi-admin" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source        = "../../govwifi-admin"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  ami             = "${var.ami}"
  ssh-key-name    = "${var.ssh-key-name}"
  users           = "${var.users}"
  aws-region      = "${var.aws-region}"
  aws-region-name = "${var.aws-region-name}"
  vpc-id          = "${module.backend.backend-vpc-id}"
  instance-count  = 2
  min-size        = 2

  admin-docker-image      = "${format("%s/admin:production", var.docker-image-path)}"
  rack-env                = "production"
  secret-key-base         = "${var.admin-secret-key-base}"
  ecs-instance-profile-id = "${module.backend.ecs-instance-profile-id}"
  ecs-service-role        = "${module.backend.ecs-service-role}"

  subnet-ids = "${module.backend.backend-subnet-ids}"

  elb-sg-list = []

  ec2-sg-list = []

  db-sg-list = []

  admin-db-user     = "${var.admin-db-username}"
  admin-db-password = "${var.admin-db-password}"

  db-instance-count        = 1
  db-instance-type         = "db.t2.large"
  db-storage-gb            = 120
  db-backup-retention-days = 1
  db-encrypt-at-rest       = true
  db-maintenance-window    = "sat:00:42-sat:01:12"
  db-backup-window         = "03:42-04:42"
  db-monitoring-interval   = 60

  rr-db-user     = "${var.db-user}"
  rr-db-password = "${var.db-password}"
  rr-db-host     = "rr.london.wifi.service.gov.uk"
  rr-db-name     = "govwifi_wifi"

  user-db-user     = "${var.user-db-username}"
  user-db-password = "${var.user-db-password}"
  user-db-host     = "${var.user-rr-hostname}"
  user-db-name     = "govwifi_production_users"

  critical-notifications-arn = "${module.critical-notifications.topic-arn}"
  capacity-notifications-arn = "${module.capacity-notifications.topic-arn}"

  rds-monitoring-role = "${module.backend.rds-monitoring-role}"

  notify-api-key             = "${var.notify-api-key}"
  london-radius-ip-addresses = "${var.london-radius-ip-addresses}"
  dublin-radius-ip-addresses = "${var.dublin-radius-ip-addresses}"
  sentry-dsn                 = "${var.admin-sentry-dsn}"
  public-google-api-key      = "${var.public-google-api-key}"

  otp-secret-encryption-key = "${var.otp-secret-encryption-key}"

  logging-api-search-url = "https://api-elb.london.${var.Env-Subdomain}.service.gov.uk:8443/logging/authentication/events/search/"

  zendesk-api-endpoint = "https://govuk.zendesk.com/api/v2/"
  zendesk-api-user     = "${var.zendesk-api-user}"
  zendesk-api-token    = "${var.zendesk-api-token}"

  bastion-ips = [
    "${split(",", var.bastion-server-IP)}",
    "${split(",", var.backend-subnet-IPs)}",
  ]
}

module "api" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source        = "../../govwifi-api"
  env           = "production"
  Env-Name      = "${var.Env-Name}"
  Env-Subdomain = "${var.Env-Subdomain}"

  ami                    = "${var.ami}"
  ssh-key-name           = "${var.ssh-key-name}"
  users                  = "${var.users}"
  backend-elb-count      = 1
  backend-instance-count = 2
  backend-min-size       = 1
  backend-cpualarm-count = 1
  aws-account-id         = "${var.aws-account-id}"
  aws-region-name        = "${var.aws-region-name}"
  aws-region             = "${var.aws-region}"
  route53-zone-id        = "${var.route53-zone-id}"
  vpc-id                 = "${module.backend.backend-vpc-id}"
  iam-count              = 1

  critical-notifications-arn = "${module.critical-notifications.topic-arn}"
  capacity-notifications-arn = "${module.capacity-notifications.topic-arn}"
  devops-notifications-arn   = "${module.devops-notifications.topic-arn}"

  auth-docker-image         = "${format("%s/authorisation-api:production", var.docker-image-path)}"
  user-signup-docker-image  = "${format("%s/user-signup-api:production", var.docker-image-path)}"
  logging-docker-image      = "${format("%s/logging-api:production", var.docker-image-path)}"
  safe-restart-docker-image = "${format("%s/safe-restarter:production", var.docker-image-path)}"
  notify-api-key            = "${var.notify-api-key}"

  db-user                            = "${var.db-user}"
  db-password                        = "${var.db-password}"
  db-hostname                        = "db.${lower(var.aws-region-name)}.${var.Env-Subdomain}.service.gov.uk"
  db-read-replica-hostname           = "rr.${lower(var.aws-region-name)}.${var.Env-Subdomain}.service.gov.uk"
  rack-env                           = "production"
  radius-server-ips                  = "${split(",", var.frontend-radius-IPs)}"
  authentication-sentry-dsn          = "${var.auth-sentry-dsn}"
  safe-restart-sentry-dsn            = "${var.safe-restart-sentry-dsn}"
  user-signup-sentry-dsn             = "${var.user-signup-sentry-dsn}"
  logging-sentry-dsn                 = "${var.logging-sentry-dsn}"
  shared-key                         = "${var.shared-key}"
  performance-url                    = "${var.performance-url}"
  performance-dataset                = "${var.performance-dataset}"
  performance-bearer-volumetrics     = "${var.performance-bearer-volumetrics}"
  performance-bearer-completion-rate = "${var.performance-bearer-completion-rate}"
  performance-bearer-active-users    = "${var.performance-bearer-active-users}"
  performance-bearer-unique-users    = "${var.performance-bearer-unique-users}"
  performance-bearer-roaming-users   = "${var.performance-bearer-roaming-users}"
  subnet-ids                         = "${module.backend.backend-subnet-ids}"
  ecs-instance-profile-id            = "${module.backend.ecs-instance-profile-id}"
  ecs-service-role                   = "${module.backend.ecs-service-role}"
  user-signup-api-base-url           = "https://api-elb.london.${var.Env-Subdomain}.service.gov.uk:8443"
  user-db-username                   = "${var.user-db-username}"
  user-db-hostname                   = "${var.user-db-hostname}"
  user-db-password                   = "${var.user-db-password}"
  user-rr-hostname                   = "${var.user-rr-hostname}"
  admin-bucket-name                  = "govwifi-production-admin"
  background-jobs-enabled            = 1
  govnotify-bearer-token             = "${var.govnotify-bearer-token}"
  user-signup-api-is-public          = true

  elb-sg-list = []

  backend-sg-list = [
    "${module.backend.be-admin-in}",
  ]

  metrics-bucket-name = "${module.govwifi-dashboard.metrics-bucket-name}"
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
  topic-name = "govwifi-wifi-critical-london"
  emails     = ["${var.critical-notification-email}"]
}

module "govwifi-dashboard" {
  providers = {
    "aws" = "aws.AWS-main"
  }

  source   = "../../govwifi-dashboard"
  Env-Name = "${var.Env-Name}"
}
