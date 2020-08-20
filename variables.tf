#------------------------------------------------------------------------------
# DEFINE THE FOLLOWING ENVIRONMENT VARIABLES FIRST
#------------------------------------------------------------------------------
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
#------------------------------------------------------------------------------
# VARIABLES FOR THE MODULE
#------------------------------------------------------------------------------
variable "region" {
  description = "The region to deploy all resources"
  default     = "eu-central-1"
  type        = string
}

variable "website_name" {
  description = "The name of the website"
  default     = "example-1ased13"
  type        = string
}

variable "custom_tags" {
  description = "The tags to attach to the resource"
  default     = {}
  type        = map
}

variable "certificate_arn" {
  description = "Certificate ARN to attach to CloudFront"
  default     = ""
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

variable "user" {}
variable "pass" {}