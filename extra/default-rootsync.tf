terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.16.0"
    }
  }
}

provider "google" {
  project = var.project
}

variable "project" {
  type = string
  description = "GCP project ID"
}

resource "google_gke_hub_feature" "feature" {
  name = "configmanagement"
  location = "global"
  provider = google
  fleet_default_member_config {
    configmanagement {
      # version = "1.17.0" # Use the default latest version; if specifying a version, it must be at or after 1.17.0
      config_sync {
        source_format = "unstructured"
        git {
          sync_repo = "https://github.com/knee-berts/fleets-next24-demo"
          sync_branch = "dev"
          policy_dir = "default-configs"
          secret_type = "none"
        }
      }
    }
  }
}