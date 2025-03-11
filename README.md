# SAM application pipeline terraform module

This Terraform module creates a pipeline capable of deploying a sam application starting from a codecommit repository which holds a SAM application.

The repository which holds the source SAM app must be existing, it won't be created by this module

The codebuild phase of the pipeline created by this module executes a `sam deploy` command in a python3 environment.
This means that during the deploy phase of this pipeline, the Cloudformation template created by SAM will be created and applied.

## 📌 Table of Contents

- [SAM application pipeline terraform module](#sam-application-pipeline-terraform-module)
  - [📌 Table of Contents](#-table-of-contents)
  - [Providers](#providers)
  - [Inputs](#inputs)
  - [Passing Parameters to the SAM cloudformation template](#parameters-to-sam)
  - [Outputs](#outputs)
  - [Roles](#roles)
  - [📜 License](#license)

## Providers  <a name="providers"></a>

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.21.0 |

## Inputs <a name="inputs"></a>

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | The id of the account on which the SAM application will be deployed | `string` | n/a | yes |
| <a name="input_branch_name"></a> [branch\_name](#input\_branch\_name) | Codecommit branch name from which the code will be built | `string` | `"main"` | no |
| <a name="input_buildspec_template"></a> [buildspec\_template](#input\_buildspec\_template) | Contents of the buildspec to use during CodeBuild | `string` | `null` | no |
| <a name="input_create_code_commit"></a> [create\_code\_commit](#input\_create\_code\_commit) | Codecommit repository name from which the code will be built | `bool` | `true` | no |
| <a name="input_kms_custom_key_s3_id"></a> [kms\_custom\_key\_s3\_id](#input\_kms\_custom\_key\_s3\_id) | If not null bucket will be encrypt with provided key id | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the application | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region in which to create resources | `string` | n/a | yes |
| <a name="input_repository_arn"></a> [repository\_arn](#input\_repository\_arn) | Codecommit repository name from which the code will be built | `string` | `""` | no |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Codecommit repository name from which the code will be built | `string` | `"sam-service-scheduler"` | no |
| <a name="input_s3_bucket_artifact_id"></a> [s3\_bucket\_artifact\_id](#input\_s3\_bucket\_artifact\_id) | Bucket name of shared artifact bucket. If null create a dedicated bucket. | `string` | `null` | no |
| <a name="input_s3_expiration_lifecycle"></a> [s3\_expiration\_lifecycle](#input\_s3\_expiration\_lifecycle) | Expires bucket objects after n days | <pre>object({<br>    status          = optional(string, "Enabled")<br>    expiration_days = optional(number, 15)<br>  })</pre> | <pre>{<br>  "expiration_days": 15,<br>  "status": "Enabled"<br>}</pre> | no |
| <a name="input_sam_cloudformation_variables"></a> [sam\_cloudformation\_variables](#input\_sam\_cloudformation\_variables) | A map of key-value paiers which are set as Parameters of the SAM deployment cloudformation template | `map(string)` | `{}` | no |
| <a name="input_source_bucket_name"></a> [source\_bucket\_name](#input\_source\_bucket\_name) | The name of the bucket used by SAM. This bucket will be created | `string` | n/a | yes |
| <a name="input_source_bucket_prefix"></a> [source\_bucket\_prefix](#input\_source\_bucket\_prefix) | Bucket subfolder in which SAM will place its artifacts | `string` | `"artifacts"` | no |
| <a name="input_source_stage_provider"></a> [source\_stage\_provider](#input\_source\_stage\_provider) | Pipeline source stage provider to use. Allowed values S3 or CodeCommit | `string` | `"S3"` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | The name of the stack used by SAM to store cloudformation templates | `string` | n/a | yes |


## Passing Parameters to the SAM cloudformation template <a name="parameters-to-sam"></a>
The SAM app contains a Cloudformation template (usually called `template.yml`) which can be parametrized using the `Parameters` section of the template.
These parameters must be passed in some way to the template.
The way you can pass these parameters with this module is throught the `sam_cloudformation_variables` variable which is a key-value map of

`<cloudformation-parameter-name> = <cloudformation-parameter-value>`

## Outputs <a name="outputs"></a>

| Name | Description |
|------|-------------|
| <a name="output_codebuild-project-arn"></a> [codebuild-project-arn](#output\_codebuild-project-arn) | n/a |
| <a name="output_codecommit-policy-arn"></a> [codecommit-policy-arn](#output\_codecommit-policy-arn) | n/a |
| <a name="output_pipeline-arn"></a> [pipeline-arn](#output\_pipeline-arn) | n/a |
| <a name="output_source_bucket_name"></a> [source\_bucket\_name](#output\_source\_bucket\_name) | n/a |
<!-- END_TF_DOCS -->

## Roles <a name="roles"></a>
This moudule creates a role which will be applied to the Codebuild project which will build the application. This role contains three policies which:

- Allows Codebuild to read/write artifacts from/to the bucket used by Codepipeline
- Allows Codebuild to execute generic operations needed by `sam deploy` like upload SAM artifacts to s3, manage Cloudformation stacks
- Allows Cloudformation to create all the resources defined inside its template.

As the resources defined in the Cloudformation template aren't known to this module (they are specific for the SAM application which will be deployed) the latter policy is currently set to give administrator access so that cloudformation will be able to create any resource.
In the future this policy will be passed as this module's variable, so that whoever uses this module will be able to write a policy which narrows down the permissions given to Cloudformation 

## 📜 License <a name="license"></a>

This project is licensed under the [**LGPL-3 License**](https://www.gnu.org/licenses/lgpl-3.0.html#license-text).
