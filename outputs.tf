output "codecommit-policy-arn" {
  value = module.codecommit-policy[0].arn
}

output "pipeline-arn" {
  value = aws_codepipeline.be_pipeline.arn
}

output "codebuild-project-arn" {
  value = aws_codebuild_project.sam_container_build.arn
}
