provider "google" {
  project = var.project
  credentials = file("/root/.config/gcloud/legacy_credentials/xxxxx@gmail.com/adc.json")
  region  = var.region
  zone    = var.zone
}