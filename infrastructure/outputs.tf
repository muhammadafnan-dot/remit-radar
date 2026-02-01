output "frontend_cloudfront_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "backend_alb_url" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "rds_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}