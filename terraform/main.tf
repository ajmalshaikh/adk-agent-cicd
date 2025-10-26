terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.60.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "iam.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "workloadidentitypool.googleapis.com"
  ])
  project = var.project_id
  service = each.key
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "adk-agent-repo"
  description   = "Docker repo for ADK agent images"
  format        = "DOCKER"
}

resource "google_service_account" "github_actions" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

resource "google_project_iam_member" "artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_cloud_run_service" "agent" {
  name     = "adk-agent-service"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/pause:3.1"
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffics {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "invoker" {
  service = google_cloud_run_service.agent.name
  location = google_cloud_run_service.agent.location
  role = "roles/run.invoker"
  member = "allUsers" # demo; lock down in prod
}

output "artifact_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "sa_email" {
  value = google_service_account.github_actions.email
}

output "cloud_run_url" {
  value = google_cloud_run_service.agent.status[0].url
}
