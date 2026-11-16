# 1. Establish Artifact Registry repository (for storing Docker images)
resource "google_artifact_registry_repository" "my_repo" {
  location      = var.gcp_region
  repository_id = "my-repo"
  format        = "DOCKER"
}

# 2. Establish Cloud Run service (with Cloud SQL Unix Socket mounted)
resource "google_cloud_run_v2_service" "default" {
  name     = "${var.app_name}-service"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.main.connection_name]
      }
    }

    containers {
      # Defaults to gcr.io/cloudrun/hello on first apply; updated via CI/CD or var.image_url
      image = var.image_url

      ports {
        container_port = 8000
      }

      env {
        name  = "DATABASE_URL"
        value = "mysql+pymysql://${var.db_username}:${var.db_password}@/${google_sql_database.database.name}?unix_socket=/cloudsql/${google_sql_database_instance.main.connection_name}"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }

  depends_on = [
    google_project_iam_member.cloudrun_sql_client,
    google_sql_database.database,
    google_sql_user.users
  ]
}

# 3. Configure Cloud Run for public access (allowing everyone to visit)
resource "google_cloud_run_v2_service_iam_member" "noauth" {
  location = google_cloud_run_v2_service.default.location
  name     = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# 4. Establish GCP Cloud SQL (MySQL) instance
resource "google_sql_database_instance" "main" {
  name                = "${var.app_name}-db"
  database_version    = "MYSQL_8_0"
  region              = var.gcp_region
  deletion_protection = false # Set to true in production environment

  settings {
    tier = "db-f1-micro" # Test-level lightweight tier
  }
}

# 5. Establish database
resource "google_sql_database" "database" {
  name     = "inventory_db"
  instance = google_sql_database_instance.main.name
}

# 6. Establish database user
resource "google_sql_user" "users" {
  name     = var.db_username
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

# 7. Establish GCP Cloud Storage Bucket (similar to AWS S3)
resource "google_storage_bucket" "my_bucket" {
  name                     = "${var.gcp_project_id}-${var.app_name}-storage" # Bucket name must be globally unique
  location                 = var.gcp_region
  force_destroy            = true       # Test-level: Delete files within the bucket when it's destroyed
  public_access_prevention = "enforced" # Protection mechanism: Prevent public access to ensure security

  uniform_bucket_level_access = true # Adopt uniform access control permissions (recommended best practice)
}

#8. Get the default Compute Service Account information for the new project
data "google_project" "project" {}

# Automatically grant Cloud SQL Client permissions
resource "google_project_iam_member" "cloudrun_sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}