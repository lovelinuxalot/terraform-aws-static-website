#------------------------------------------------------------------------------
# OUTPUT FOR WEBSITE BUCKET NAME AND ENDPOINT
#------------------------------------------------------------------------------
output "app_bucket_website_endpoint" {
  value       = aws_s3_bucket.app_bucket.website_endpoint
  description = "Website endpoint for the S3 bucket"
}

output "app_bucket_name" {
  description = "Name of of website bucket"
  value       = aws_s3_bucket.app_bucket.id
}


#------------------------------------------------------------------------------
# OUTPUT FOR CLOUDFRONT DISTRIBUTION DOMAIN NAME AND ID TO POINT TO USE
# WITH OTHER RESOURCES
#------------------------------------------------------------------------------
output "cloudfront_distribution_domain" {
  value = aws_cloudfront_distribution.website_distribution.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website_distribution.id
}

#------------------------------------------------------------------------------
# OUTPUT FOR THE WEBSITE NAME
#------------------------------------------------------------------------------
output "domain_name_a_record" {
  value = aws_route53_record.main_a_record.fqdn
}