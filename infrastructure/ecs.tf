resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"    # 0.25 vCPU
  memory                   = "512"    # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "${aws_ecr_repository.backend.repository_url}:latest"

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
      { name = "HTTP_PORT", value = "3000" },
      { name = "TARGET_PORT", value = "3001" },
      { name = "PORT", value = "3001" },
      { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/remit_radar_production" },
      { name = "RAILS_MASTER_KEY", value = var.rails_master_key },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1             # Start with 1 task, scale later
  launch_type     = "FARGATE"

  network_configuration {
    # COST OPTIMIZATION: Using public subnets to avoid NAT Gateway cost (~$32/month)
    # Security is maintained via security groups (only ALB can access)
    # For production, consider using private subnets with NAT Gateway
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
    ]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true  # Required for public subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 3000
  }

  # Allow ECS to drain old tasks during deployment
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Enable ECS Exec for running migrations/seeds
  enable_execute_command = true
}
