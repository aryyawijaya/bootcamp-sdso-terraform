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

# VPC Network
resource "google_compute_network" "vpc" {
  name = "bootcamp-sdso"
  auto_create_subnetworks = false  # Disable auto creation of subnets
}
# Subnet in the VPC
resource "google_compute_subnetwork" "subnet" {
  name          = "bootcamp-sdso-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.name
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
  subnetwork = google_compute_subnetwork.subnet.name

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

# PostgreSQL Database
resource "google_sql_database_instance" "main" {
  name             = "bootcamp-sdso-postgresql-2"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    # Enable Private IP and assign to the VPC and subnet
    ip_configuration {
      ipv4_enabled = false  # Disables public IP
      private_network = google_compute_network.vpc.id  # Connect to VPC
    }
  }

  deletion_protection = false

  # Assign a private IP to this instance
  # private_ip_address = google_compute_subnetwork.subnet.name
}
