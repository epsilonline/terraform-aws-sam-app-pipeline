variable "role_prefix" {
  type        = string
  description = "Prefix to prepend to role, to avoid duplicates"
}

variable "codepipeline_bucket_arn" {
  type        = string
  description = "ARN of the S3 Bucket used by CodePipeline"
}

variable "region" {
  type        = string
  description = "region"
}

variable "account_id" {
  description = "The id of the account on which the SAM application will be deployed"
  type = string
}
