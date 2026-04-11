variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "email_address" {
  description = "Email to receive EC2 running notifications"
  type        = string
}