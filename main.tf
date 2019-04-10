/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.name}-${var.environment}"

  tags {
    Environment = "${var.environment}"
    Application = "${var.name}"
  }
}

/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "ecr-repository" {
  name = "${var.repository_name}"
}

/*====
ECS role
======*/

# ecs_execution_role
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.name}-${var.environment}-ecs_execution_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-execution-role.json")}"
}

resource "aws_iam_role_policy" "ecs_execution_policy" {
  name   = "${var.name}-${var.environment}-ecs_execution_policy"
  role   = "${aws_iam_role.ecs_execution_role.id}"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
}


# ecs_task_execution_role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name}-${var.environment}-ecs_task_execution_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}

resource "aws_iam_role_policy" "ecs_task_execution_role_policy" {
  name   = "${var.name}-${var.environment}-ecs_task_execution_role_policy"
  role   = "${aws_iam_role.ecs_task_execution_role.id}"
  policy = "${var.ecs_task_execution_role_policy}"
}

# ecs task
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.name}-${var.environment}"
  container_definitions    = "${var.container_definition}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.task_cpu}"
  memory                   = "${var.task_memory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_task_execution_role.arn}"
}


/*====
App Load Balancer
======*/

resource "aws_alb_target_group" "alb_target_group" {
  count    = "${var.add_loadbalancer ? 1 : 0}"
  name     = "${var.name}-${var.environment}"
  port     = "${var.container_port}"
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path    = "${var.health_check_path}"
    matcher = "${var.health_check_matcher}"
  }
  depends_on = ["aws_alb.alb_ecs"]
}

/* security group for ALB */
resource "aws_security_group" "web_inbound_sg" {
  count       = "${var.add_loadbalancer ? 1 : 0}"
  name        = "${var.name}-${var.environment}-web-inbound-sg"
  description = "Allow HTTP and HTTPS from Anywhere into ALB"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.name}-${var.environment}-web-inbound-sg"
  }
}

resource "aws_alb" "alb_ecs" {
  count           = "${var.add_loadbalancer ? 1 : 0}"
  name            = "${var.name}-${var.environment}-alb"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.web_inbound_sg.id}"]

  tags {
    Name        = "${var.environment}-${var.name}-alb"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "alb_listener" {
  count             = "${var.add_loadbalancer ? 1 : 0}"
  load_balancer_arn = "${aws_alb.alb_ecs.arn}"
  port              = "80"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.alb_target_group","aws_alb.alb_ecs"]

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}

/*
* IAM service role
*/
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "${var.name}-${var.environment}-ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

/* ecs service scheduler role */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "${var.name}-${var.environment}-ecs_service_role_policy"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role   = "${aws_iam_role.ecs_role.id}"
}


/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.name}-${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "web" {
  task_definition = "${aws_ecs_task_definition.web.family}"
  depends_on = ["aws_ecs_task_definition.web"]
}

### Service Registry resources
locals {
  # service_registries block does not accept a port with "A"-record-type
  # Setting the port to false works through a local
  service_registries_container_port = {
    "SRV" = "${var.container_port}"
    "A"   = false
  }
}

resource "aws_service_discovery_private_dns_namespace" "namespace" {
  name        = "${var.name}.local"
  description = "Description"
  vpc         = "${var.vpc_id}"
}

resource "aws_service_discovery_service" "service" {

  name = "${var.name}"

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.namespace.id}"

    dns_records {
      ttl  = "${var.service_discovery_dns_ttl}"
      type = "${var.service_discovery_dns_type}"
    }

    routing_policy = "${var.service_discovery_routing_policy}"
  }

  health_check_custom_config {
    failure_threshold = "${var.service_discovery_healthcheck_custom_failure_threshold}"
  }
}
### ECS Service
resource "aws_ecs_service" "web" {
  count           = "${var.add_loadbalancer ? 1 : 0}"
  name             = "${var.name}-${var.environment}"
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = "${var.cluster_id}"
  health_check_grace_period_seconds = "${var.health_check_grace_period_seconds}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy","aws_ecs_task_definition.web","data.aws_ecs_task_definition.web"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  depends_on = ["aws_alb_target_group.alb_target_group","aws_alb.alb_ecs"]
}

resource "aws_ecs_service" "web_no_alb" {
  count           = "${1 - var.add_loadbalancer}"
  name             = "${var.name}-${var.environment}"
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = "${var.cluster_id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy","aws_ecs_task_definition.web","data.aws_ecs_task_definition.web"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

#  service_registries = {
#    registry_arn   = "${aws_service_discovery_service.service.arn}"
#    container_name = "${var.container_name}"
#    container_port = "${local.service_registries_container_port[var.service_discovery_dns_type]}"
#  }
}


