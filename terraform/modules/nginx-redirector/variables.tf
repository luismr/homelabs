variable "namespace" {
  type = string
}

variable "name" {
  type    = string
  default = "redirector"
}

variable "replicas" {
  type    = number
  default = 1
}

# Each rule defines a set of source hostnames and a target hostname.
# Wildcard sources (e.g., *.example.com) mirror the subdomain to the target.
variable "rules" {
  type = list(object({
    sources = list(string)
    target  = string
    code    = optional(number)
  }))
  default = []
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 4
}

variable "target_cpu_utilization_percentage" {
  description = "Average CPU utilization percentage target for HPA"
  type        = number
  default     = 60
}

variable "target_memory_utilization_percentage" {
  description = "Average memory utilization percentage target for HPA"
  type        = number
  default     = 70
}


