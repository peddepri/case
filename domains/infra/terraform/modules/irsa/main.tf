data "aws_iam_policy_document" "irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^.*://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^.*://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "irsa" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = toset(var.policy_arns)
  
  role       = aws_iam_role.irsa.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "irsa_inline" {
  for_each = var.inline_policies
  
  name   = each.key
  role   = aws_iam_role.irsa.id
  policy = each.value
}