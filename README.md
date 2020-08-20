# terraform-aws-static-website

## Introduction
The terraform module can be reused for creating a static website.

## Components for the static website

- 3 S3 buckets:
  - Serve website
  - Serve static content for the website
  - Store logs from both the buckets
  
- Cloudfront
  - Web distribution
  - Cache behaviours:
    - default: Website bucket
    - /static: Static content bucket
  - Web ACLS attached with WAF
  - Custom Certificate

- Route 53
  - Hosted Zone
  - A Record
  - CNAME record(Optional) 
  
## Functionality

The module does the following function:

- Take the ARN of an **ACM** certificate as a parameter.
- Create the **S3** buckets with best practices configuration.
- Create **Route53 HostedZone**
- Create the **Cloudfront** distribution
- Create the **DNS** entry to point to the Cloudfront distribution
- **IP protection** to the distribution to specified IP ranges.

## Prerequisites
### To run module
- Install [Terraform](https://www.terraform.io/) and make sure its on your `PATH`

### To test module
- Install [Terraform](https://www.terraform.io/) and make sure its on your `PATH`
- Install [Golang](https://golang.org/) and make sure this code is checked out into your `GOPATH`.

 ## Usage
 ### To run module
 
 - Clone the repository
 - Create a main.tf file to import the module
 - Add all necessary values there, or create the main.tf file with all values as vars
 - Create a TFVars file and add all variables in the file
 - If the website files needs to be uploaded with terraform, add code in the module that sources this module and add 
 the `aws_s3_bucket_object` resource to upload the files. Most probably `index.html` and `error.html`. The other option
 would be to create the resources and manually upload the code from UI or CLI
 - **NOTE**: When uploading static content to static content s3 bucket, ensure all content will be in a directory `static`.
 For ex: `/static/css/style.css` in the index.html, should have the content in static s3 bucket: `static/css/style.css`
 - Configure your AWS credentials using one of the [supported methods for AWS CLI tools](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html), such as setting the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables. If you're using the `~/.aws/config` file for profiles then export `AWS_SDK_LOAD_CONFIG` as "True".
 - Run `terraform init` to initialize the module
 - Run `terraform plan` to verify if everything is okay with syntax
 - Run `terraform apply` to apply the changes and create the website
 - To destroy the resources run `terraform destroy`
 
 ### To test module
- Clone the repository
- `cd test`
- `dep ensure`
- For unit testing run `go test -v -tags=unit -timeout 0`
- For integration testing run `go test -v -tags=integration -timeout 0`

####NOTE: 
- For unit testing, Terraform plan is only run and ensure all resources are created
- For integration testing, its Terraform apply and destroy. So all resources will be created. Make sure its okay to have
the resources created or if you are in the free tier
- Timeout for `go test` should be passed as go program will run into panic and exit after the default timeout of `10 minute` is
reached

## User Input Variables

|Variable name | Description | Type |Default value or example |
|---|---|---|---|
|region| The region to deploy the resources | string | `eu-central-1`|
|website_name| The name of Hosted Zone or Domain name| string | `example.com`|
|custom_tags| The tags to provide for the resources created| map | `{}`|
|certificate_arn| The ARN of the ACM certificate to attach to Cloudfront distribution | string| `arn:aws:acm:us-east-1:xxxxxxxx:certificate/xxxxxxxxx`| 
|cidr_whitelist| The list of IP ranges to allow access to the Cloudfront distribution | list | `[0.0.0.0/0]`
|forward_www_cname| To add a CNAME record for the provided domain name | boolean | `false`|


## Outputs

| Name | Description|
|---|---|
|app_bucket_website_endpoint| The website endpoint of the S3 bucket that hosts the website |
|app_bucket_name| The application or website hosting bucket name |
|cloudfront_distribution_domain| The Cloudfront distribution domain name |
|cloudfront_distribution_id| The ID of the Cloudfront distribution |
|domain_name_a_record| The A Record created for the website |

## Examples
- An Example on how to run the module is added in the examples folder


## Important Information
- The ACM certificate provided as input should have the domain name in the certificate. If the certificate do not have 
the `www` subdomain in the certificate, please make sure to provide `forward_www_cname` as `false` or leave it as 
the `default` is `false`. 
- The website can be hosted with the S3 bucket by enabling `static website hosting` and pass the website block in the 
S3 bucket code. This is fine when not using / using Cloudfront
- With Cloudfront, I opted to not enable the option, so that the bucket is not totally public and can be accessed by 
Cloudfront only. This has an added security on the buckets itself.
- The buckets are encrypted with `Amazon S3 Server side encryption` with `AES256` encryption. I tried with `AWS KMS` and 
I faced issues with Cloudfront to access the bucket. Either I had maybe not configured correctly the permissions. 
But I thought to stick with `AES256` as its managed by S3 itself.
- The tests are written with Terratest, so make sure all dependencies are there
- Integration testing has always resource provisioned. So make sure that its okay if the resources are provisioned
