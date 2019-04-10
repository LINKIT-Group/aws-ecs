output "repository_url" {
  value = "${aws_ecr_repository.ecr-repository.repository_url}"
}

output "cluster_name" {
  value = "${var.cluster_name}"
}

output "container_name" {
  value = "${var.container_name}"
}

output "name" {
  value = "${var.name}"
}

output "container_port" {
  value = "${var.container_port}"
}

output "cloudwatch_log_group_name" {
  value = "${aws_cloudwatch_log_group.log-group.name}"
}

output "service_name" {
  value = "${element(concat(aws_ecs_service.web.*.name, list("")), 0)}"
}

output "service_name_no_alb" {
  value = "${element(concat(aws_ecs_service.web_no_alb.*.name, list("")), 0)}"
}

output "alb_dns_name" {
  value = "${element(concat(aws_alb.alb_ecs.*.dns_name, list("")), 0)}"
}

output "alb_zone_id" {
  value = "${element(concat(aws_alb.alb_ecs.*.zone_id, list("")), 0)}"
}

output "security_group_id" {
  value = "${aws_security_group.ecs_service.id}"
}
