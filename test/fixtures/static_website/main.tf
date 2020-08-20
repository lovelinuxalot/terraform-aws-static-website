provider "aws" {
  region = var.region
}

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

module "website" {
  source            = "../../../"
  website_name      = var.website_name
  forward_www_cname = var.forward_www_cname
  certificate_arn   = var.certificate_arn
  cidr_whitelist    = var.cidr_whitelist
  custom_tags       = var.custom_tags
  region            = var.region
}