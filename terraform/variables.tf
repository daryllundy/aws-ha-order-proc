variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "ha-order-proc"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Spot workers"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to Spot workers"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for workers"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "record_name" {
  description = "Subdomain record for failover endpoint"
  type        = string
  default     = "orders"
}

variable "primary_service_fqdn" {
  description = "Primary regional endpoint DNS name"
  type        = string
}

variable "config_repo_url" {
  description = "Git URL used by ansible-pull from EC2"
  type        = string
}

variable "config_repo_ref" {
  description = "Git ref for ansible-pull"
  type        = string
  default     = "main"
}
