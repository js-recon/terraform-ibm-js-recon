# Changelog

## 1.0.1 — Unreleased

## 1.0.0 — 2026-07-10

Initial release.

- IBM Code Engine Job running JS Recon against any URL using the Puppeteer Docker image
- Optional IBM Cloud Object Storage bucket for artifact storage with IAM service ID/API key
- Inputs mirroring the GitHub Action and GitLab CI component: `url`, `js_recon_version`, `break_on_map_files`, `break_on_vulnerabilities`, `vulnerability_severity`, `output_dir`
- Outputs: `code_engine_job_name`, `code_engine_job_id`, `code_engine_project_id`, `cos_bucket_name`, `cos_instance_id`, `iam_service_id`
- Examples: `basic/` (on-demand) and `scheduled/` (documents cron scheduling via IBM Cloud CLI)
