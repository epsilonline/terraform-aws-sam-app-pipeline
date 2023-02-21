terraform {
  required_providers {
    aws = {
      source  = "aws"
      version = "~> 4.40.0"
    }
  }
}

#########################################
# CodeCommit
#########################################

resource "aws_codecommit_repository" "sam_codecommit_repo" {
  count           = var.source_stage_provider == "CodeCommit" ? 1 : 0
  repository_name = var.repository_name
  description     = "Create CodeCommit repository only if source stage pipeline starts from CodeCommit"
}

# data "aws_codecommit_repository" "source_repository" {  //To_delete?
#   repository_name = var.repository_name
# }

module "codecommit-policy" {
  count  = var.source_stage_provider == "CodeCommit" ? 1 : 0
  source = "git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-policy-codecommit.git"

  policy_name            = "${var.repository_name}-codecommit-policy"
  codecommit_repo_arn    = aws_codecommit_repository.sam_codecommit_repo[0].arn
  codecommit_repo_branch = var.branch_name
}


#########################################
# CodeBuild
#########################################
module "codebuild-role" {
  source = "./terraform-modules/iam-role-codebuild"

  codepipeline_bucket_arn = aws_s3_bucket.be_artifact_bucket.arn
  region                  = var.region
  role_prefix             = var.name
  account_id              = var.account_id
}

locals {
  parameter_overrides_list = [for key, value in var.sam_cloudformation_variables : "${key}=$${${key}}"]
  parameter_overrides      = join(" ", local.parameter_overrides_list)
}

data "template_file" "buildspec" {
  template = file("${path.module}/buildspec.yaml")
  vars = {
    parameter_overrides = local.parameter_overrides
  }
}


resource "aws_codebuild_project" "sam_container_build" {
  badge_enabled  = false
  build_timeout  = 60
  name           = var.name
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
      name = "SOURCE_BUCKET_NAME"
      ## NAME OF THE BUCKET USED BY SAM, to be created inside this terraform
      value = var.source_bucket_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name = "SOURCE_BUCKET_PREFIX"
      ## ARN OF THE BUCKET USED BY SAM, to be created inside this terraform
      value = var.source_bucket_prefix
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "REGION"
      value = var.region
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "SAM_CLOUDFORMATION_KEYS"
      value =format("%#v",keys(var.sam_cloudformation_variables))
      type  = "PLAINTEXT"
    }

    dynamic "environment_variable" {
      for_each = var.sam_cloudformation_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
        type  = "PLAINTEXT"
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

#########################################
# Pipeline
#########################################

module "pipeline-role" {

  source      = "git::git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-role-pipeline?ref=v1.0"
  role_prefix = var.name
}

resource "aws_s3_bucket" "sam-bucket" {
  bucket = var.source_bucket_name
}
resource "aws_s3_bucket_versioning" "sam-bucket-versioning" {
  bucket = aws_s3_bucket.sam-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket" "be_artifact_bucket" {
  bucket = "${var.name}-pipeline-artifacts"

}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.be_artifact_bucket.id
  acl    = "private"
}

resource "aws_codepipeline" "be_pipeline" {
  name     = var.name
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
      provider = var.source_stage_provider

      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {

        # Case Source S3
        S3Bucket       = var.source_stage_provider == "S3" ? aws_s3_bucket.sam-bucket.bucket : null
        S3ObjectKey    = var.source_stage_provider == "S3" ? "source.zip" : null

        # Case Source CodeCommit
        RepositoryName = var.source_stage_provider == "CodeCommit" ? aws_codecommit_repository.sam_codecommit_repo[0].repository_name : null
        BranchName     = var.source_stage_provider == "CodeCommit" ? var.branch_name : null

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
