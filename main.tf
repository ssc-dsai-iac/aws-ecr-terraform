# ---------------------------------------------------------------------------------------------------------------------
# Elastic Container Registry (ECR)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  encryption_configuration {
    encryption_type = var.encryption_type == "KMS" ? var.encryption_type : "AES256"
    kms_key         = var.kms_key
  }

  image_scanning_configuration {
    scan_on_push = var.scan_images_on_push
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Elastic Container Registry (ECR) Policies
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "authorization_token_access" {
  statement {
    sid    = "GetAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "allow_pull_access" {
  statement {
    sid    = "AllowPull"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

data "aws_iam_policy_document" "allow_push_access" {
  statement {
    sid    = "AllowPush"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = join(data.aws_iam_policy_document.authorization_token_access.json, data.aws_iam_policy_document.allow_pull_access.json, data.aws_iam_policy_document.allow_push_access.json)
}


# ---------------------------------------------------------------------------------------------------------------------
# Elastic Container Registry (ECR) Lifecycle Policies
# ---------------------------------------------------------------------------------------------------------------------
# locals {
#   untagged_image_rule = [{
#     rulePriority = length(var.protected_tags) + 1
#     description  = "Remove untagged images"
#     selection = {
#       tagStatus   = "untagged"
#       countType   = "imageCountMoreThan"
#       countNumber = 1
#     }
#     action = {
#       type = "expire"
#     }
#   }]

#   remove_old_image_rule = [{
#     rulePriority = length(var.protected_tags) + 2
#     description  = "Rotate images when reach ${var.max_image_count} images stored",
#     selection = {
#       tagStatus   = "any"
#       countType   = "imageCountMoreThan"
#       countNumber = var.max_image_count
#     }
#     action = {
#       type = "expire"
#     }
#   }]

#   protected_tag_rules = [
#     for index, tagPrefix in zipmap(range(length(var.protected_tags)), tolist(var.protected_tags)) :
#     {
#       rulePriority = tonumber(index) + 1
#       description  = "Protects images tagged with ${tagPrefix}"
#       selection = {
#         tagStatus     = "tagged"
#         tagPrefixList = [tagPrefix]
#         countType     = "imageCountMoreThan"
#         countNumber   = 999999
#       }
#       action = {
#         type = "expire"
#       }
#     }
#   ]
# }

# resource "aws_ecr_lifecycle_policy" "name" {
#   for_each   = toset(module.this.enabled && var.enable_lifecycle_policy ? local.image_names : [])
#   repository = aws_ecr_repository.name[each.value].name

#   policy = jsonencode({
#     rules = concat(local.protected_tag_rules, local.untagged_image_rule, local.remove_old_image_rule)
#   })
# }