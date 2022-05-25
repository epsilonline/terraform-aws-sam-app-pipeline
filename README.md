# SAM application pipeline terraform module

This Terraform module creates a pipeline capable of deploying a sam application starting from a codecommit repository which holds a SAM application.

The repository which holds the source SAM app must be existing, it won't be created by this module

The codebuild phase of the pipeline created by this module executes a `sam deploy` command in a python3 environment.
This means that during the deploy phase of this pipeline, the Cloudformation template created by SAM will be created and applied.

## Passing Parameters to the SAM cloudformation template
The SAM app contains a Cloudformation template (usually called `template.yml`) which can be parametrized using the `Parameters` section of the template.
These parameters must be passed in some way to the template.
The way you can pass these parameters with this module is throught the `sam_cloudformation_variables` variable which is a key-value map of

`<cloudformation-parameter-name> = <cloudformation-parameter-value>`

## Roles
This moudule creates a role which will be applied to the Codebuild project which will build the application. This role contains three policies which:

- Allows Codebuild to read/write artifacts from/to the bucket used by Codepipeline
- Allows Codebuild to execute generic operations needed by `sam deploy` like upload SAM artifacts to s3, manage Cloudformation stacks
- Allows Cloudformation to create all the resources defined inside its template.

As the resources defined in the Cloudformation template aren't known to this module (they are specific for the SAM application which will be deployed) the latter policy is currently set to give administrator access so that cloudformation will be able to create any resource.
In the future this policy will be passed as this module's variable, so that whoever uses this module will be able to write a policy which narrows down the permissions given to Cloudformation 
