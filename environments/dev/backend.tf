terraform {
  backend "gcs" {
    bucket = "project-caadee7a-7323-444d-91a-tfstate"
    prefix = "env/dev"
  }
}
