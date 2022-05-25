variable "account_id" {
  description = "The id of the account on which the SAM application will be deployed"
  type = string
}

variable "repository_name" {
  description = "Codecommit repository name from which the code will be built"
  type = string
}

variable "branch_name" {
  description = "Codecommit branch name from which the code will be built"
  type = string
}

variable "region" {
  type = string
  description = "The AWS region in which to create resources"
}

variable "application_name" {
  type = string
  description = "The name of the application"
}

variable "stack_name" {
  type = string
  description = "The name of the stack used by SAM to store cloudformation templates"
}

variable "source_bucket_name" {
  type = string
  description = "The name of the bucket used by SAM. This bucket will be created"
}

variable "source_bucket_prefix" {
  type = string
  description = "Bucket subfolder in which SAM will place its artifacts"
}

variable "sam_cloudformation_variables" {
  type = map(string)
  description = "A map of key-value paiers which are set as Parameters of the SAM deployment cloudformation template"
  default = {}
}
