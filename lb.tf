module "lb" {
  source = "./network-load-balancer"
  name   = "rancher"

  enable_health_check = true
  health_check_port   = "80"
  health_check_path   = "/"

  firewall_target_tags = ["rancher"]

  instances = google_compute_instance.rke.*.self_link
}