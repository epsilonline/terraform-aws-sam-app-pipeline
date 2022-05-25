terraform {
  required_providers {
    aws = {
      source  = "aws"
      version = "~> 4.0.0"
    }
  }
}

data "aws_codecommit_repository" "source_repository" {
  repository_name = var.repository_name
}

module "codecommit-policy" {
  source = "git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-policy-codecommit.git"

  policy_name = "${var.application_name}-codecommit-policy"
  codecommit_repo_arn = data.aws_codecommit_repository.source_repository.arn
  codecommit_repo_branch = var.branch_name
}


############# CODEBUILD ###############
module "codebuild-role" {
  source = "./terraform-modules/iam-role-codebuild"

  codepipeline_bucket_arn = aws_s3_bucket.be_artifact_bucket.arn
  region = var.region
  role_prefix = var.application_name
  account_id = var.account_id
}

resource "aws_s3_bucket" "sam-bucket" {
  bucket = var.source_bucket_name
}

locals {
  parameter_overrides_list = [for key, value in var.lambda_env_variables : "${key}=$${${key}}"]
  parameter_overrides = join(" ", local.parameter_overrides_list)
}

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yaml")}"
  vars = {
    parameter_overrides = local.parameter_overrides
  }
}


resource "aws_codebuild_project" "sam_container_build" {
  badge_enabled  = false
  build_timeout  = 60
  name           = var.application_name
  queued_timeout = 480
  service_role   = module.codebuild-role.arn
#  tags           = var.tags

  artifacts {
    encryption_disabled    = false
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "STACK_NAME"
      value = var.stack_name
    }

    environment_variable {
      name  = "SOURCE_BUCKET_NAME"
      ## ARN OF THE BUCKET USED BY SAM, to be created inside this terraform
      value = var.source_bucket_name
      type = "PLAINTEXT"
    }

    environment_variable {
      name  = "SOURCE_BUCKET_PREFIX"
      ## ARN OF THE BUCKET USED BY SAM, to be created inside this terraform
      value = var.source_bucket_prefix
      type = "PLAINTEXT"
    }

    environment_variable {
      name  = "REGION"
      value = var.region
      type = "PLAINTEXT"
    }

    dynamic "environment_variable" {
      for_each = var.lambda_env_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
        type = "PLAINTEXT"
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  source {
    buildspec           = data.template_file.buildspec.rendered
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }

}


############# PIPELINE ##############
module "pipeline-role" {

  source = "git::git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-role-pipeline?ref=v1.0"
  role_prefix = var.application_name
}

resource "aws_s3_bucket" "be_artifact_bucket" {
  bucket = "${var.application_name}-pipeline-artifacts"

}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.be_artifact_bucket.id
  acl    = "private"
}


resource "aws_codepipeline" "be_pipeline" {
  name     = var.application_name
  role_arn = module.pipeline-role.arn

  artifact_store {
    location = aws_s3_bucket.be_artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeCommit"

      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = var.repository_name
        BranchName     = var.branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.sam_container_build.name
      }
    }
  }
}
