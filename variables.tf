variable "type_of_instance" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "key_pair" {
  description = "Default SSH key"
  default     = "aws_softwarenetic"
}

variable "schedule" {
  type        = string
  default     = "cron(0 0/3 * * ? *)"
  description = "Every 3 hours"
}
