resource "aws_iam_role" "codebuild-service-role" {
  name = "${var.role_prefix}-codebuild-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild-policy" {
  role = aws_iam_role.codebuild-service-role.name
  name = "${var.role_prefix}-codebuild-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "${var.codepipeline_bucket_arn}",
                "${var.codepipeline_bucket_arn}/*"
            ],
            "Action": [
                "s3:*"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases",
                "codebuild:BatchPutCodeCoverages"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Action": [
                "cloudformation:CreateChangeSet"
            ]
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy" "sam-deploy-policy" {
  role = aws_iam_role.codebuild-service-role.name
  name = "${var.role_prefix}-deploy-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudFormationTemplate",
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateChangeSet"
            ],
            "Resource": [
                "arn:aws:cloudformation:*:aws:transform/Serverless-2016-10-31"
            ]
        },
        {
            "Sid": "CloudFormationStack",
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateChangeSet",
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeChangeSet",
                "cloudformation:DescribeStackEvents",
                "cloudformation:DescribeStacks",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:GetTemplateSummary",
                "cloudformation:ListStackResources",
                "cloudformation:UpdateStack"
            ],
            "Resource": [
                "arn:aws:cloudformation:*:${var.account_id}:stack/*"
            ]
        },
        {
            "Sid": "S3",
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::*/*"
            ]
        },
        {
            "Sid": "IAM",
            "Effect": "Allow",
            "Action": [
                "iam:AttachRolePolicy",
                "iam:DeleteRole",
                "iam:DetachRolePolicy",
                "iam:GetRole",
                "iam:TagRole",
                "iam:CreateRole",
                "iam:getRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy"
            ],
            "Resource": [
                "arn:aws:iam::${var.account_id}:role/*"
            ]
        },
        {
            "Sid": "IAMPassRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "lambda.amazonaws.com"
                }
            }
        }
    ]
}
POLICY
}


#resource "aws_iam_role_policy" "sam-application-policy" {
#  role = aws_iam_role.codebuild-service-role.name
#  name = "${var.role_prefix}-sam-application-policy"
#
#  policy = <<POLICY
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Sid": "Lambda",
#            "Effect": "Allow",
#            "Action": [
#                "lambda:AddPermission",
#                "lambda:CreateFunction",
#                "lambda:DeleteFunction",
#                "lambda:GetFunction",
#                "lambda:GetFunctionConfiguration",
#                "lambda:ListTags",
#                "lambda:RemovePermission",
#                "lambda:TagResource",
#                "lambda:UntagResource",
#                "lambda:UpdateFunctionCode",
#                "lambda:UpdateFunctionConfiguration"
#            ],
#            "Resource": [
#                "arn:aws:lambda:*:${var.account_id}:function:*"
#            ]
#        },
#        {
#            "Sid": "Cloudwatch",
#            "Effect": "Allow",
#            "Action": [
#              "events:*"
#            ],
#            "Resource": "*"
#        }
#    ]
#}
#POLICY
#}

resource "aws_iam_role_policy" "sam-application-policy" {
  role = aws_iam_role.codebuild-service-role.name
  name = "${var.role_prefix}-application-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "adminAccess",
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}
POLICY
}
