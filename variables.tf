variable "project_id" {}

variable "region" {
  default = "us-east4"
}

variable "zone" {
  default = "us-east4-a"
}

variable "gke_cluster_name" {
  default = "bootcamp-sdso"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "node_pool_machine_type" {
  default = "e2-micro"
}
