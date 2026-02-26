terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_sqs_queue" "orders" {
  name                        = "${var.name_prefix}.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  visibility_timeout_seconds  = 60
  message_retention_seconds   = 86400
}

resource "aws_dynamodb_table" "orders" {
  name         = "${var.name_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "OrderID"

  attribute {
    name = "OrderID"
    type = "S"
  }
}

resource "aws_iam_role" "worker" {
  name = "${var.name_prefix}-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "worker" {
  name = "${var.name_prefix}-worker-policy"
  role = aws_iam_role.worker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.orders.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.name_prefix}-worker-profile"
  role = aws_iam_role.worker.name
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  vpc_security_group_ids = var.security_group_ids

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    config_repo_url = var.config_repo_url
    config_repo_ref = var.config_repo_ref
    aws_region      = var.aws_region
    queue_url       = aws_sqs_queue.orders.id
    ddb_table       = aws_dynamodb_table.orders.name
  }))
}

resource "aws_autoscaling_group" "worker" {
  name                = "${var.name_prefix}-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  health_check_type = "EC2"
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-worker"
    propagate_at_launch = true
  }
}

resource "aws_s3_bucket" "standby" {
  bucket_prefix = "${var.name_prefix}-standby-"
}

resource "aws_s3_bucket_public_access_block" "standby" {
  bucket                  = aws_s3_bucket.standby.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "standby" {
  bucket = aws_s3_bucket.standby.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "standby_index" {
  bucket       = aws_s3_bucket.standby.id
  key          = "index.html"
  content_type = "text/html"
  content      = "<html><body><h1>Regional failover page</h1><p>Orders service is in standby mode.</p></body></html>"
}

resource "aws_s3_bucket_policy" "standby" {
  bucket = aws_s3_bucket.standby.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.standby.arn}/*"
    }]
  })
}

resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_service_fqdn
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "primary" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = 60
  records = [var.primary_service_fqdn]
  failover_routing_policy { type = "PRIMARY" }
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "secondary" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = 60
  records = [aws_s3_bucket_website_configuration.standby.website_endpoint]
  failover_routing_policy { type = "SECONDARY" }
  set_identifier = "secondary"
}
