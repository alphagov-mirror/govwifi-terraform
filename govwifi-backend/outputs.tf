output "backend-vpc-id" {
  value = aws_vpc.wifi-backend.id
}

output "backend-subnet-ids" {
  value = aws_subnet.wifi-backend-subnet.*.id
}

output "ecs-instance-profile-id" {
  value = aws_iam_instance_profile.ecs-instance-profile.id
}

output "ecs-service-role" {
  value = aws_iam_role.ecs-service-role.arn
}

output "rds-monitoring-role" {
  value = aws_iam_role.rds-monitoring-role.arn
}

output "be-admin-in" {
  value = aws_security_group.be-admin-in.id
}

output "vpc-cidr-block" {
  value = var.vpc-cidr-block
}

