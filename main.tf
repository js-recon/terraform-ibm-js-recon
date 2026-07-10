locals {
  cos_instance_name = var.cos_instance_name != "" ? var.cos_instance_name : "${var.job_name}-cos-${random_string.cos_suffix[0].result}"
  cos_bucket_name   = var.cos_bucket_name != "" ? var.cos_bucket_name : "${var.job_name}-${random_string.cos_suffix[0].result}"
}

resource "random_string" "cos_suffix" {
  count   = var.create_cos_bucket && (var.cos_instance_name == "" || var.cos_bucket_name == "") ? 1 : 0
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# ─── Resource group ───────────────────────────────────────────────────────────

data "ibm_resource_group" "js_recon" {
  name = var.resource_group
}

# ─── IBM Cloud Object Storage ─────────────────────────────────────────────────

resource "ibm_resource_instance" "cos" {
  count             = var.create_cos_bucket ? 1 : 0
  name              = local.cos_instance_name
  resource_group_id = data.ibm_resource_group.js_recon.id
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  tags              = var.tags
}

resource "ibm_cos_bucket" "artifacts" {
  count                = var.create_cos_bucket ? 1 : 0
  bucket_name          = local.cos_bucket_name
  resource_instance_id = ibm_resource_instance.cos[0].id
  region_location      = var.cos_bucket_region
  storage_class        = "standard"
}

# ─── IAM service ID and API key for COS upload ────────────────────────────────

resource "ibm_iam_service_id" "js_recon" {
  count = var.create_cos_bucket ? 1 : 0
  name  = "${var.job_name}-cos-writer"
  tags  = var.tags
}

resource "ibm_iam_service_policy" "cos_writer" {
  count          = var.create_cos_bucket ? 1 : 0
  iam_service_id = ibm_iam_service_id.js_recon[0].id
  roles          = ["Writer"]

  resources {
    service              = "cloud-object-storage"
    resource_instance_id = element(split(":", ibm_resource_instance.cos[0].id), 7)
  }
}

resource "ibm_iam_service_api_key" "cos_writer" {
  count          = var.create_cos_bucket ? 1 : 0
  name           = "${var.job_name}-cos-apikey"
  iam_service_id = ibm_iam_service_id.js_recon[0].iam_id
}

# ─── Code Engine project ──────────────────────────────────────────────────────

resource "ibm_code_engine_project" "js_recon" {
  name              = var.project_name
  resource_group_id = data.ibm_resource_group.js_recon.id
}

# ─── Code Engine job ──────────────────────────────────────────────────────────

resource "ibm_code_engine_job" "js_recon" {
  project_id      = ibm_code_engine_project.js_recon.project_id
  name            = var.job_name
  image_reference = "ghcr.io/puppeteer/puppeteer:24.43.1"

  run_mode                 = "task"
  scale_cpu_limit          = var.job_cpu
  scale_memory_limit       = var.job_memory
  scale_max_execution_time = var.build_timeout
  scale_retry_limit        = 0

  run_commands = ["/bin/bash", "-c", <<-SCRIPT
    set -e
    npm config set prefix /home/pptruser/.npm-global
    export PATH="/home/pptruser/.npm-global/bin:$PATH"

    echo "[js-recon] Installing @shriyanss/js-recon@$JSR_VERSION..."
    npm install -g "@shriyanss/js-recon@$JSR_VERSION"
    INSTALLED_VERSION=$(js-recon --version 2>/dev/null || echo "unknown")
    echo "[js-recon] Installed version: $INSTALLED_VERSION"

    echo "[js-recon] Running js-recon against $JSR_URL..."
    js-recon run -u "$JSR_URL" -o "$JSR_OUTPUT_DIR" --no-sandbox -y -k || {
      echo "[js-recon] ERROR: js-recon run failed."
      exit 1
    }
    echo "[js-recon] Scan complete."

    HOST_DIR=$(echo "$JSR_URL" | sed 's|https\?://||' | sed 's|[/?].*||' | tr ':' '_')
    mkdir -p "$JSR_OUTPUT_DIR/$HOST_DIR"
    for f in analyze.json mapped.json mapped-openapi.json endpoints.json strings.json report.html report.db js-recon.db; do
      [ -f "$f" ] && mv "$f" "$JSR_OUTPUT_DIR/$HOST_DIR/" 2>/dev/null || true
    done

    MAP_FILES=$(find "$JSR_OUTPUT_DIR" -name "*.map" 2>/dev/null | head -50)
    if [ -n "$MAP_FILES" ]; then
      echo "[js-recon] Source map files detected:"
      echo "$MAP_FILES"
      if [ "$JSR_BREAK_ON_MAP" = "true" ]; then
        echo "[js-recon] ERROR: Source map files are publicly accessible. Set break_on_map_files = false to suppress."
        exit 1
      fi
    fi

    ANALYZE_JSON=$(find "$JSR_OUTPUT_DIR" -name "analyze.json" 2>/dev/null | head -1)
    if [ -n "$ANALYZE_JSON" ] && [ "$JSR_BREAK_ON_VULNS" = "true" ]; then
      node -e "
    const fs = require('fs');
    const RANK = {info: 0, low: 1, medium: 2, high: 3};
    let findings = [];
    try { findings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); } catch {
      console.log('[js-recon] analyze.json is empty or invalid. Skipping.');
      process.exit(0);
    }
    if (!Array.isArray(findings) || findings.length === 0) {
      console.log('[js-recon] No findings in analyze.json.');
      process.exit(0);
    }
    const severity = process.argv[2];
    const threshold = RANK[severity] ?? 3;
    const matched = findings.filter(f => (RANK[f.severity?.toLowerCase()] ?? -1) >= threshold);
    if (matched.length === 0) {
      console.log('[js-recon] No findings at or above severity \"' + severity + '\".');
      process.exit(0);
    }
    console.log('[js-recon] ' + matched.length + ' finding(s) at or above severity \"' + severity + '\":\n');
    console.log('Rule'.padEnd(40) + ' ' + 'Severity'.padEnd(10) + ' Location');
    console.log('-'.repeat(80));
    for (const f of matched) {
      const rule = (f.ruleName || f.ruleId || 'unknown').substring(0, 39).padEnd(40);
      const sev  = (f.severity || '?').padEnd(10);
      const loc  = f.findingLocation || '';
      console.log(rule + ' ' + sev + ' ' + loc);
    }
    console.log('\n[js-recon] ERROR: ' + matched.length + ' vulnerability/vulnerabilities at severity \"' + severity + '\" or above.');
    process.exit(matched.length > 255 ? 255 : matched.length);
      " "$ANALYZE_JSON" "$JSR_SEVERITY" || exit 1
    fi

    if [ -n "$JSR_COS_BUCKET" ] && [ -n "$JSR_COS_API_KEY" ]; then
      echo "[js-recon] Uploading artifacts to IBM COS..."
      ENDPOINT="https://s3.$JSR_COS_REGION.cloud-object-storage.appdomain.cloud"
      TOKEN_RESP=$(curl -s -X POST "https://iam.cloud.ibm.com/identity/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$JSR_COS_API_KEY")
      IAM_TOKEN=$(node -e "console.log(JSON.parse(process.argv[1]).access_token)" "$TOKEN_RESP")
      for f in $(find "$JSR_OUTPUT_DIR" -type f); do
        KEY="$JSR_COS_PREFIX/$(echo "$f" | sed "s|$JSR_OUTPUT_DIR/||")"
        curl -s -X PUT "$ENDPOINT/$JSR_COS_BUCKET/$KEY" \
          -H "Authorization: Bearer $IAM_TOKEN" \
          -T "$f" || echo "[js-recon] WARN: Failed to upload $f"
      done
      echo "[js-recon] Artifacts uploaded to $JSR_COS_BUCKET/$JSR_COS_PREFIX/"
    fi
  SCRIPT
  ]

  run_env_variables {
    name  = "JSR_URL"
    value = var.url
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_VERSION"
    value = var.js_recon_version
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_BREAK_ON_MAP"
    value = tostring(var.break_on_map_files)
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_BREAK_ON_VULNS"
    value = tostring(var.break_on_vulnerabilities)
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_SEVERITY"
    value = var.vulnerability_severity
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_OUTPUT_DIR"
    value = var.output_dir
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_COS_BUCKET"
    value = var.create_cos_bucket ? local.cos_bucket_name : ""
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_COS_REGION"
    value = var.cos_bucket_region
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_COS_PREFIX"
    value = var.cos_artifact_prefix
    type  = "literal"
  }
  run_env_variables {
    name  = "JSR_COS_API_KEY"
    value = var.create_cos_bucket ? ibm_iam_service_api_key.cos_writer[0].apikey : ""
    type  = "literal"
  }
  run_env_variables {
    name  = "PUPPETEER_SKIP_DOWNLOAD"
    value = "true"
    type  = "literal"
  }
  run_env_variables {
    name  = "IS_DOCKER"
    value = "true"
    type  = "literal"
  }
  run_env_variables {
    name  = "NODE_OPTIONS"
    value = "--max-http-header-size=99999999"
    type  = "literal"
  }
  run_env_variables {
    name  = "PUPPETEER_CACHE_DIR"
    value = "/home/pptruser/.cache/puppeteer"
    type  = "literal"
  }
}
