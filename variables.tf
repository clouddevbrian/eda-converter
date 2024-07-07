variable "queue_name" {
  description = "The name of the MediaConvert queue."
  type        = string
  default     = "example-queue"
}

variable "queue_description" {
  description = "The description of the MediaConvert queue."
  type        = string
  default     = "Example MediaConvert queue"
}

variable "queue_status" {
  description = "The status of the MediaConvert queue. Valid values: ACTIVE, PAUSED."
  type        = string
  default     = "ACTIVE"
}

variable "pricing_plan" {
  description = "The pricing plan for the MediaConvert queue. Valid values: ON_DEMAND, RESERVED."
  type        = string
  default     = "ON_DEMAND"
}
