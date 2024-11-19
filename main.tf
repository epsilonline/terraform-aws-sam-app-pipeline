terraform {
  required_providers {
    aws = {
      source  = "aws"
      version = ">= 4.0"
    }
  }
}

locals {
  parameter_overrides_list = [for key, value in var.sam_cloudformation_variables : "${key}=$${${key}}"]
  parameter_overrides      = join(" ", local.parameter_overrides_list)
  buildspec_template       = var.buildspec_template == null ? "${path.module}/buildspec.yaml" : var.buildspec_template
  create_code_commit       = var.create_code_commit == true && var.source_stage_provider == "CodeCommit"
  code_commit_arn          = local.create_code_commit ? aws_codecommit_repository.sam_codecommit_repo[0].arn : var.repository_arn
}

#########################################
# CodeCommit
#########################################

resource "aws_codecommit_repository" "sam_codecommit_repo" {
  count           = local.create_code_commit ? 1 : 0
  repository_name = var.repository_name
  description     = "Create CodeCommit repository only if source stage pipeline starts from CodeCommit"
}

module "codecommit-policy" {
  count   = var.source_stage_provider == "CodeCommit" ? 1 : 0
  #source = "git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-policy-codecommit.git"
  version = "~> 1"
  source  = "gitlab.com/epsilonline/iam-policy-codecommit/aws"
  policy_name            = "${var.name}-codecommit-policy"
  codecommit_repo_arn    = local.code_commit_arn
  codecommit_repo_branch = var.branch_name
}


#########################################
# CodeBuild
#########################################
module "codebuild-role" {
  source = "./terraform-modules/iam-role-codebuild"

  codepipeline_bucket_arn = var.s3_bucket_artifact_id == null ? aws_s3_bucket.be_artifact_bucket[0].arn : data.aws_s3_bucket.shared_bucket[0].arn
  region                  = var.region
  role_prefix             = substr(var.name, 0, )
  account_id              = var.account_id
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
    buildspec           = templatefile(local.buildspec_template, { parameter_overrides = local.parameter_overrides })
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }

}

#########################################
# Pipeline
#########################################

data "aws_s3_bucket" "shared_bucket" {
  count  = var.s3_bucket_artifact_id != null ? 1 : 0
  bucket = var.s3_bucket_artifact_id
}

module "pipeline-role" {

  #source      = "git::git@gitlab.com:epsilonline/terraform-modules/terraform-aws-iam-role-pipeline?ref=v1.0"
  source       = "gitlab.com/epsilonline/iam-role-pipeline/aws"
  version               = "~> 1"
  role_prefix  = var.name
}

resource "aws_s3_bucket" "sam-bucket" {
  bucket = var.source_bucket_name
}

data "aws_kms_key" "s3" {
  count = var.kms_custom_key_s3_id != null ? 1 : 0
  key_id = var.kms_custom_key_s3_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sam-bucket-encryption" {

  count = var.kms_custom_key_s3_id != null ? 1 : 0

  bucket = aws_s3_bucket.sam-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_kms_key.s3[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "sam-bucket-versioning" {
  bucket = aws_s3_bucket.sam-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket" "be_artifact_bucket" {
  count  = var.s3_bucket_artifact_id == null ? 1 : 0
  bucket = "${var.name}-pipeline-artifacts"
}

resource "aws_s3_bucket_ownership_controls" "be_artifact_bucket" {
  count  = var.s3_bucket_artifact_id == null ? 1 : 0
  bucket = aws_s3_bucket.be_artifact_bucket[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  count  = var.s3_bucket_artifact_id == null ? 1 : 0
  bucket = aws_s3_bucket.be_artifact_bucket[0].id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.be_artifact_bucket
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "delete_objects" {
  count  = var.s3_bucket_artifact_id == null ? 1 : 0
  bucket = aws_s3_bucket.be_artifact_bucket[0].id
  rule {
    status = var.s3_expiration_lifecycle.status
    id     = "expire_all_files"

    expiration {
      days = var.s3_expiration_lifecycle.expiration_days
    }
  }
}

resource "aws_codepipeline" "be_pipeline" {
  name     = var.name
  role_arn = module.pipeline-role.arn

  artifact_store {
    location = var.s3_bucket_artifact_id == null ? aws_s3_bucket.be_artifact_bucket[0].bucket : var.s3_bucket_artifact_id
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
        S3Bucket    = var.source_stage_provider == "S3" ? aws_s3_bucket.sam-bucket.bucket : null
        S3ObjectKey = var.source_stage_provider == "S3" ? "source.zip" : null

        # Case Source CodeCommit
        RepositoryName = var.source_stage_provider == "CodeCommit" ? var.repository_name : null
        BranchName     = var.source_stage_provider == "CodeCommit" ? var.branch_name : null

        PollForSourceChanges = false


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

#########################################
# Cloudwatch event
#########################################

resource "aws_iam_role" "cloudwatch_app_source" {
  name = substr("${var.name}-event-source", 0, 64)
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "app_source_trigger" {
  name = "${var.name}-event-source"
  role = aws_iam_role.cloudwatch_app_source.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codepipeline:StartPipelineExecution"
      ],
      "Resource": [
        "${aws_codepipeline.be_pipeline.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "s3_source" {
  name = "${var.name}-event-rule"

  event_pattern = <<PATTERN
  {
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutObject", "CompleteMultipartUpload", "CopyObject"],
    "requestParameters": {
      "bucketName": ["${aws_s3_bucket.sam-bucket.bucket}"],
      "key": ["source.zip"]
    }
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "app_source" {
  rule      = aws_cloudwatch_event_rule.s3_source.name
  target_id = "CodePipeline"
  arn       = aws_codepipeline.be_pipeline.arn
  role_arn  = aws_iam_role.cloudwatch_app_source.arn
}