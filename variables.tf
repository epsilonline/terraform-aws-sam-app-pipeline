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
  description = "The name of the bucket"
}

variable "source_bucket_prefix" {
  type = string
  description = "The name of the bucket"
}

variable "lambda_env_variables" {
  type = map(string)
  description = "A map of key-value environment variables which will be set on the lambda function of this SAM deployment"
  default = {}
}
