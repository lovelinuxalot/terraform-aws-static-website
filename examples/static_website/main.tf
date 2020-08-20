#------------------------------------------------------------------------
# Configure Provider
#------------------------------------------------------------------------

provider "aws" {
  region = var.region
}

#------------------------------------------------------------------------
# Configure Variables, to get variables from TF VARS file
#------------------------------------------------------------------------
variable "region" {
  description = "The region to deploy all resources"
  default     = "eu-central-1"
  type        = string
}

variable "website_name" {
  description = "The name of the website"
  default     = "example.com"
  type        = string
}

variable "custom_tags" {
  description = "The tags to attach to the resource"
  default = {
    name = "Testing"
  }
  type = map
}

variable "certificate_arn" {
  description = "Certificate ARN to attach to CloudFront"
  default     = "my-cert-arn"
  type        = string
}

variable "cidr_whitelist" {
  description = "The list of CIDRs to whitelist when accessing CloudFront"
  type        = list
  default     = ["0.0.0.0/0"]
}

variable "forward_www_cname" {
  description = "To add forwarding www.domainname.com to domainname.com. Should be enabled only the certificate has support for www.domainname.com"
  default     = false
  type        = bool
}

#------------------------------------------------------------------------
# Use the Module for static website
#------------------------------------------------------------------------
module "static_website" {
  source            = "../../"
  region            = var.region
  website_name      = var.website_name
  forward_www_cname = var.forward_www_cname
  certificate_arn   = var.certificate_arn
  cidr_whitelist    = var.cidr_whitelist
  custom_tags       = var.custom_tags
}

#------------------------------------------------------------------------
# Create resources for index and error file for testing
#------------------------------------------------------------------------
resource "aws_s3_bucket_object" "index" {
  key          = "index.html"
  bucket       = module.static_website.app_bucket_name
  source       = "src/index.html"
  acl          = "public-read"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "error" {
  key          = "error.html"
  bucket       = module.static_website.app_bucket_name
  source       = "src/error.html"
  acl          = "public-read"
  content_type = "text/html"
}

#------------------------------------------------------------------------
# The website endpoint on which the website is hosted
#------------------------------------------------------------------------

output "website_endpoint" {
  value = module.static_website.domain_name_a_record
}