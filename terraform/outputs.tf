output "queue_url" {
  value = aws_sqs_queue.orders.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.orders.name
}

output "asg_name" {
  value = aws_autoscaling_group.worker.name
}

output "standby_website_endpoint" {
  value = aws_s3_bucket_website_configuration.standby.website_endpoint
}
