output "codecommit-policy-arn" {
  value = var.source_stage_provider == "CodeCommit" ? module.codecommit-policy[0].arn : null
}

output "pipeline-arn" {
  value = aws_codepipeline.be_pipeline.arn
}

output "codebuild-project-arn" {
  value = aws_codebuild_project.sam_container_build.arn
}
