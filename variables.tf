variable "region" {
  type = string
  default = "eu-central-1"
  description = "AWS region where the tarpit experiment should be run"

  validation {
    condition     = can(regex("[a-z][a-z]-[a-z]+-[1-9]", var.region))
    error_message = "Must be valid AWS region"
  }
}
