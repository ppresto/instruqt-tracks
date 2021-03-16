resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "ppresto-ec2"
  role        = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "ec2_role" {
  name_prefix        = "ppresto-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_role.json
}

data "aws_iam_policy_document" "ec2_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ec2_discovery" {
  name   = "ppresto-ec2-cluster_discovery"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_discovery.json
}

data "aws_iam_policy_document" "ec2_discovery" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "autoscaling:CompleteLifecycleAction",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucketVersions",
      "s3:ListBucket",
    ]
    resources = [
      "*"
    ]
  }

}
