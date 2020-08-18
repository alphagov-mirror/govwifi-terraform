# CNAME for all radius servers for this environment
resource "aws_route53_record" "radius" {
  count      = "${var.radius-instance-count}"
  zone_id    = "${var.route53-zone-id}"
  name       = "${format("radius%d.%s.service.gov.uk", var.dns-numbering-base + count.index + 1, var.Env-Subdomain)}"
  type       = "CNAME"
  ttl        = "300"
  records    = ["${element(aws_instance.radius.*.public_dns, count.index)}"]
  depends_on = ["aws_instance.radius", "aws_eip_association.eip_assoc"]
}

resource "aws_route53_health_check" "radius" {
  count             = "${aws_eip_association.eip_assoc.count}"
  # before merging on to master, the commented out line needs re-enabling
  # reference_name    = "${format("${var.Env-Name}-${var.aws-region-name}-frontend-%d", count.index + 1)}"
  reference_name    = "${format("${var.Env-Name}-frontend-%d", count.index + 1)}"
  ip_address        = "${element(aws_eip_association.eip_assoc.*.public_ip, count.index)}"
  port              = 3000
  type              = "HTTP"
  request_interval  = "30"
  failure_threshold = "3"
  measure_latency   = true

  tags = {
    Name = "${format("${var.Env-Name}-${var.aws-region-name}-%d", count.index + 1)}"
  }
}
