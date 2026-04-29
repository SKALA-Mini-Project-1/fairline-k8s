locals {
  base_name = "${var.name_prefix}-${var.environment}"

  common_tags = merge(
    {
      Project     = "fairline"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.common_tags
  )
}
