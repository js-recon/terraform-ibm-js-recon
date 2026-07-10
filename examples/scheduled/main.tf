provider "ibm" {
  region = "us-south"
  # ibmcloud_api_key = var.ibmcloud_api_key  # set via IC_API_KEY env var
}

module "js_recon" {
  source = "../../"

  url      = "https://example.com"
  schedule = "0 8 * * *"

  break_on_map_files       = true
  break_on_vulnerabilities = true
  vulnerability_severity   = "high"

  tags = ["security"]
}

output "code_engine_job_name" {
  value = module.js_recon.code_engine_job_name
}

output "cos_bucket_name" {
  value = module.js_recon.cos_bucket_name
}
