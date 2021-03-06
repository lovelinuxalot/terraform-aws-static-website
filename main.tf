#------------------------------------------------------------------------------
# Static Website with S3, Cloudfront and WAF to allow requests from certain IP Ranges
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# PIN TERRAFORM VERSION >= 0.12
#------------------------------------------------------------------------------
terraform {
  required_version = ">=0.12"
}

#------------------------------------------------------------------------------
# DEFINE THE PROVIDERS
#------------------------------------------------------------------------------
provider "aws" {
  region = var.region
}

#------------------------------------------------------------------------------
# DEFINING LOCAL VARIABLES TO USE WITH RESOURCES
#------------------------------------------------------------------------------
locals {
  static_bucket_name = "${var.website_name}-static.com"
  app_bucket_name    = "${var.website_name}-app.com"
  app_name_id        = element(split(".", var.website_name), 0)
  tmp_path           = "${path.module}/tmp"
}

#------------------------------------------------------------------------------
# IAM POLICY TO ATTACH TO APPLICATION CONTENT BUCKET AS BUCKET POLICY
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "app_bucket_policy" {
  version   = "2012-10-17"
  policy_id = "AppBucketPolicy"
  statement {
    sid    = "AllowCloudFrontReadOnly"
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.app_bucket.arn}/*",
    ]
  }
}

#------------------------------------------------------------------------------
# IAM POLICY TO ATTACH TO STATIC CONTENT BUCKET AS BUCKET POLICY
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "static_bucket_policy" {
  version   = "2012-10-17"
  policy_id = "StaticBucketPolicy"
  statement {
    sid    = "AllowCloudFrontReadOnly"
    effect = "Allow"
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.s3_bucket_cloudfront_oai.iam_arn]
      type        = "AWS"
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.static_bucket.arn}/*",
    ]
  }
}

#------------------------------------------------------------------------------
# S3 BUCKET FOR LOGGING
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${var.website_name}-log"
  acl           = "log-delivery-write"
  force_destroy = true

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }
}

#------------------------------------------------------------------------------
# S3 BUCKET TO SERVE STATIC CONTENT
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "static_bucket" {
  bucket        = local.static_bucket_name
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log-static/"
  }

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }
}

#------------------------------------------------------------------------------
# S3 BUCKET POLICY FOR STATIC BUCKET
#------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "static_bucket_policy" {
  bucket = aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.static_bucket_policy.json
}

#------------------------------------------------------------------------------
# S3 BUCKET TO SERVE APPLICATION AS A STATIC WEBSITE
#------------------------------------------------------------------------------
resource "aws_s3_bucket" "app_bucket" {
  bucket        = local.app_bucket_name
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log-app/"
  }

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }

}

#------------------------------------------------------------------------------
# S3 BUCKET POLICY FOR APPLICATION BUCKET
#------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.id
  policy = data.aws_iam_policy_document.app_bucket_policy.json
}

#------------------------------------------------------------------------------
# CREATE ORIGIN ACCESS IDENTITY FOR CLOUDFRONT FOR S3 BUCKETS
#------------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_identity" "s3_bucket_cloudfront_oai" {
  comment = "${var.website_name}-cloudfront-access-oai"
}

#------------------------------------------------------------------------------
# CREATE CLOUDFRONT DISTRIBUTION FOR THE WEBSITE
#------------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "website_distribution" {
  enabled = true

  aliases             = compact(list(var.website_name, var.forward_www_cname ? "www.${var.website_name}" : null))
  default_root_object = "index.html"
  web_acl_id          = aws_waf_web_acl.waf_acl.id
  comment             = "Managed by Terraform"

  logging_config {
    bucket = aws_s3_bucket.log_bucket.bucket_regional_domain_name
    prefix = "log-cf/"
  }

  origin {
    domain_name = aws_s3_bucket.app_bucket.bucket_regional_domain_name
    origin_id   = local.app_bucket_name

    s3_origin_config {
      origin_access_identity = join("/", ["origin-access-identity/cloudfront", aws_cloudfront_origin_access_identity.s3_bucket_cloudfront_oai.id])
    }
  }

  origin {
    domain_name = aws_s3_bucket.static_bucket.bucket_regional_domain_name
    origin_id   = local.static_bucket_name

    s3_origin_config {
      origin_access_identity = join("/", ["origin-access-identity/cloudfront", aws_cloudfront_origin_access_identity.s3_bucket_cloudfront_oai.id])
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.app_bucket_name

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

  }

  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.static_bucket_name

    viewer_protocol_policy = "https-only"
    forwarded_values {
      query_string = false
      cookies {
        forward = "all"
      }
    }
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2019"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }
}

#------------------------------------------------------------------------------
# CREATE A HOSTEDZONE
#------------------------------------------------------------------------------
resource "aws_route53_zone" "main" {
  name    = var.website_name
  comment = "Managed by Terraform"
}

#------------------------------------------------------------------------------
# CREATE A 'A' RECORD FOR CLOUDFRONT DISTRIBUTION
#------------------------------------------------------------------------------
resource "aws_route53_record" "main_a_record" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.website_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

#------------------------------------------------------------------------------
# CREATE A CNAME RECORD TO POINT TO THE WEBSITE
#------------------------------------------------------------------------------
resource "aws_route53_record" "main_c_name" {
  count   = var.forward_www_cname ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = "300"
  records = [var.website_name]
}

#------------------------------------------------------------------------------
# CREATE WAF IPSET FROM THE CIDR PROVIDED
#------------------------------------------------------------------------------
resource "aws_waf_ipset" "ip_whitelist" {
  name = "${local.app_name_id}_ip_whitelist"

  dynamic "ip_set_descriptors" {
    for_each = toset(var.cidr_whitelist)
    content {
      type  = "IPV4"
      value = ip_set_descriptors.key
    }
  }
}

#------------------------------------------------------------------------------
# CREATE WAF RULE
#------------------------------------------------------------------------------
resource "aws_waf_rule" "ip_whitelist" {
  metric_name = "${local.app_name_id}ipwhitelist"
  name        = "${local.app_name_id}_ip_whitelist_rule"

  depends_on = [aws_waf_ipset.ip_whitelist]

  predicates {
    data_id = aws_waf_ipset.ip_whitelist.id
    negated = false
    type    = "IPMatch"
  }

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }

}

#------------------------------------------------------------------------------
# CREATE WAF ACL
#------------------------------------------------------------------------------
resource "aws_waf_web_acl" "waf_acl" {
  metric_name = "${local.app_name_id}wafacl"
  name        = "${local.app_name_id}_waf_acl"

  default_action {
    type = "BLOCK"
  }

  rules {
    priority = 10
    rule_id  = aws_waf_rule.ip_whitelist.id

    action {
      type = "ALLOW"
    }
  }

  depends_on = [
    aws_waf_ipset.ip_whitelist,
    aws_waf_rule.ip_whitelist
  ]

  tags = { for tag_name, tag_value in var.custom_tags : tag_name => tag_value }

}



