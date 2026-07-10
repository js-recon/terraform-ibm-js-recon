output "code_engine_job_name" {
  description = "Name of the Code Engine Job"
  value       = ibm_code_engine_job.js_recon.name
}

output "code_engine_job_id" {
  description = "ID of the Code Engine Job"
  value       = ibm_code_engine_job.js_recon.job_id
}

output "code_engine_project_id" {
  description = "ID of the Code Engine project"
  value       = ibm_code_engine_project.js_recon.project_id
}

output "cos_bucket_name" {
  description = "Name of the IBM COS bucket where JS Recon artifacts are stored"
  value       = var.create_cos_bucket ? ibm_cos_bucket.artifacts[0].bucket_name : var.cos_bucket_name
}

output "cos_instance_id" {
  description = "Resource ID of the IBM COS service instance"
  value       = var.create_cos_bucket ? ibm_resource_instance.cos[0].id : null
}

output "iam_service_id" {
  description = "IAM service ID used by the job to write to COS"
  value       = var.create_cos_bucket ? ibm_iam_service_id.js_recon[0].iam_id : null
}
