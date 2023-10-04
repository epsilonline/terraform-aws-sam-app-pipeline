variable "account_id" {
  description = "The id of the account on which the SAM application will be deployed"
  type        = string
}

variable "repository_name" {
  description = "Codecommit repository name from which the code will be built"
  type        = string
  default     = "sam-service-scheduler"
}

variable "repository_arn" {
  description = "Codecommit repository name from which the code will be built"
  type        = string
  default     = ""
}

variable "create_code_commit" {
  description = "Codecommit repository name from which the code will be built"
  type        = bool
  default     = true
}



variable "branch_name" {
  description = "Codecommit branch name from which the code will be built"
  type        = string
  default     = "main"
}

variable "region" {
  type        = string
  description = "The AWS region in which to create resources"
}

variable "name" {
  type        = string
  description = "The name of the application"
}

variable "stack_name" {
  type        = string
  description = "The name of the stack used by SAM to store cloudformation templates"
}

variable "source_bucket_name" {
  type        = string
  description = "The name of the bucket used by SAM. This bucket will be created"
}

variable "source_bucket_prefix" {
  type        = string
  description = "Bucket subfolder in which SAM will place its artifacts"
  default     = "artifacts"
}

variable "sam_cloudformation_variables" {
  type        = map(string)
  description = "A map of key-value paiers which are set as Parameters of the SAM deployment cloudformation template"
  default     = {}
}

variable "source_stage_provider" {
  type        = string
  description = "Pipeline source stage provider to use. Allowed values S3 or CodeCommit"
  default     = "S3"
}

variable "s3_bucket_artifact_id" {
  type        = string
  default     = null
  description = "Bucket name of shared artifact bucket. If null create a dedicated bucket."
}

variable "buildspec_template" {
  type        = string
  default     = null
  description = "Contents of the buildspec to use during CodeBuild"
}

variable "s3_expiration_lifecycle" {
  description = "Expires bucket objects after n days"
  type = object({
    status          = optional(string, "Enabled")
    expiration_days = optional(number, 15)
  })
  validation {
    condition     = contains(["Enabled", "Disabled"], var.s3_expiration_lifecycle.status)
    error_message = "The status must be either 'Enabled' or 'Disabled'"
  }
  default = {
    status = "Enabled"
    expiration_days = 15
  }
}