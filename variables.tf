variable "ecs_task_execution_role_policy" {
  description = "set your own render policy"
#  default = "${data.template_file.ecs_task_execution_role_policy.rendered}"
  default = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}



variable "add_loadbalancer" {
  description = "add loadbalancer and target group"
  default = false
}

variable "loadbalancer_dns" {
  description = "DNS address to connect to"
  default = ""
}

variable "cluster_id" {
  description = "Cluster if to which you want to add service"
}

variable "cluster_name" {
  description = "Cluster name to use for codepipeline"
}

variable "name" {
  description = "name of the Application will be used to give names to services"
}

variable "region" {
  description = "region"
}

variable "environment" {
  description = "The environment will be used to give names to services"
}

variable "vpc_id" {
  description = "The VPC id"
}

variable "availability_zones" {
  type        = "list"
  description = "The azs to use"
}

variable "security_groups_ids" {
  type        = "list"
  description = "The SGs to use"
}

variable "subnets_ids" {
  type        = "list"
  description = "The private subnets to use"
}

variable "public_subnet_ids" {
  type        = "list"
  description = "The private subnets to use"
}

variable "repository_name" {
  description = "The name of the repisitory"
}

variable "task_cpu" {
  description = "The number of cpu units used by the task"
}

variable "task_memory" {
  description = "The amount (in MiB) of memory used by the task"
}

variable "container_port" {
  description = "port number on which your application is in the container default is 80"
  default = "80"
}

variable "health_check_grace_period_seconds" {
  description = "The period of time, in seconds, that the Amazon ECS service scheduler should ignore unhealthy Elastic Load Balancing target health checks after a task has first started for testing use high number"
  default = "120"
}

variable "container_name" {
  description = "Name of container in service"
}

variable "container_definition" {
  description = "Container definition in JSON"
}

variable "health_check_path" {
  description = "ALB health check path"
  default = "/"
}

variable "health_check_matcher" {
  description = "ALB health check matcher for example 200 and 302"
  default = "200"
}

# Service Discovery DNS TTL
variable "service_discovery_dns_ttl" {
  default = "60"
}

# Service Discovery DNS Type
variable "service_discovery_dns_type" {
  default = "A"
}

# Service Discovery routing policy
variable "service_discovery_routing_policy" {
  default = "MULTIVALUE"
}

# Service Discovery customer failure thresholds, needs to be set to at least 1
variable "service_discovery_healthcheck_custom_failure_threshold" {
  default = "1"
}
