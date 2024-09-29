provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Service Account
resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}
resource "google_project_iam_binding" "gke_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.default.email}"
  ]
}

# VPC
resource "google_compute_network" "vpc" {
  name = "bootcamp-sdso"
}

# GKE Cluster
data "google_container_engine_versions" "gke_version" {
  location       = var.region
  version_prefix = "1.30."
}

resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network = google_compute_network.vpc.name

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name     = google_container_cluster.primary.name
  location = var.region
  cluster  = google_container_cluster.primary.name

  version    = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    disk_size_gb = 10
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = var.node_pool_machine_type
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Enable Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
