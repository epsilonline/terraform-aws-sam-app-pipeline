# SAM application pipeline terraform module

This Terraform module creates a pipeline capable of deploying a sam application starting from a codecommit repository which holds a SAM application.

The repository which holds the source SAM app must be existing, it won't be created by this module

The codebuild phase of the pipeline created by this module executes a `sam deploy` command in a python3 environment.
This means that during the deploy phase of this pipeline, the Cloudformation template created by SAM will be created and applied.

## Passing Parameters to the SAM cloudformation template
The SAM app contains a Cloudformation template (usually called `template.yml`) which can be parametrized using the `Parameters` section of the template.
These parameters must be passed in some way to the template.
The way you can pass these parameters with this module is throught the `sam_cloudformation_variables` variable which is a key-value map of `<cloudformation-parameter-name> = <cloudformatio-parameter-value>`
