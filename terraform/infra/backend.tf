terraform {
  backend "gcs" {
    bucket = "mathgpt-tf-state"
    prefix = "terraform/state/infra"
  }
  required_providers {
    google     = { source = "hashicorp/google", version = "~> 4.0" }
  }
}
