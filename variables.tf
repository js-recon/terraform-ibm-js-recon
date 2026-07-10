variable "url" {
  description = "Target URL to scan (e.g. https://example.com or http://localhost:3000)"
  type        = string
}

variable "js_recon_version" {
  description = "JS Recon version to install — passed to npm install -g @shriyanss/js-recon@<version> (e.g. latest, alpha, 1.3.1-beta.1)"
  type        = string
  default     = "latest"
}

variable "break_on_map_files" {
  description = "Fail the job if .map source map files are detected in the output"
  type        = bool
  default     = true
}

variable "break_on_vulnerabilities" {
  description = "Fail the job if vulnerabilities at or above the configured severity are detected"
  type        = bool
  default     = true
}

variable "vulnerability_severity" {
  description = "Minimum severity to fail on: low, medium, or high"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["low", "medium", "high"], var.vulnerability_severity)
    error_message = "vulnerability_severity must be one of: low, medium, high"
  }
}

variable "output_dir" {
  description = "Directory inside the container where JS Recon output files are saved"
  type        = string
  default     = "js-recon-output"
}

variable "project_name" {
  description = "Name of the IBM Code Engine project (created if it does not exist)"
  type        = string
  default     = "js-recon"
}

variable "job_name" {
  description = "Name for the Code Engine Job"
  type        = string
  default     = "js-recon"
}

variable "region" {
  description = "IBM Cloud region where Code Engine and COS resources are created (e.g. us-south, eu-de)"
  type        = string
  default     = "us-south"
}

variable "resource_group" {
  description = "IBM Cloud resource group name"
  type        = string
  default     = "default"
}

variable "job_cpu" {
  description = "CPU units allocated to each Code Engine Job run (e.g. 1, 2, 4)"
  type        = string
  default     = "2"
}

variable "job_memory" {
  description = "Memory allocated to each Code Engine Job run (e.g. 4G, 8G)"
  type        = string
  default     = "4G"
}

variable "create_cos_bucket" {
  description = "Whether to create an IBM Cloud Object Storage bucket for storing JS Recon output artifacts"
  type        = bool
  default     = true
}

variable "cos_instance_name" {
  description = "Name of the IBM COS service instance. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "cos_bucket_name" {
  description = "Name of the COS bucket. Must be globally unique. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "cos_bucket_region" {
  description = "COS bucket storage region (e.g. us-south, eu-de, ap-north)"
  type        = string
  default     = "us-south"
}

variable "cos_artifact_prefix" {
  description = "Object key prefix for uploaded artifacts inside the COS bucket"
  type        = string
  default     = "js-recon-output"
}

variable "schedule" {
  description = "Cron expression for automated scans via Code Engine periodic timer (e.g. 0 8 * * *). Leave empty to disable."
  type        = string
  default     = ""
}

variable "build_timeout" {
  description = "Maximum duration in seconds for a single Code Engine Job run"
  type        = number
  default     = 1800
}

variable "tags" {
  description = "Tags to apply to IBM Cloud resources"
  type        = list(string)
  default     = []
}
