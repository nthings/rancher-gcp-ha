provider "google" {
  credentials = file("./credentials.json")
  project     = var.gcp_project
  region      = var.gcp_region
}

data "google_compute_zones" "available" {}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-1604-lts"
  project = "ubuntu-os-cloud"
}

resource "random_id" "worker_instance_id" {
  count       = var.nodes
  byte_length = 8
}

resource "google_compute_firewall" "firewall" {
  name    = "rke-node-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  # These IP ranges are required for health checks
  source_ranges = ["0.0.0.0/0"]

  # Target tags define the instances to which the rule applies
  target_tags = ["rancher"]
}

resource "google_compute_instance" "rke" {
  count        = var.nodes
  name         = "rke-gcp-${random_id.worker_instance_id[count.index].hex}"
  machine_type = "n1-standard-1"
  zone         = data.google_compute_zones.available.names[count.index]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  metadata = {
    ssh-keys = "demo:${file("~/keys/aws_terraform.pub")}"
  }

  tags = ["rancher"]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "demo"
      private_key = file("~/keys/aws_terraform")
      host        = self.network_interface.0.access_config.0.nat_ip
    }

    inline = [
      "sudo curl -sSL https://get.docker.com/ | sh",
      "sudo usermod -aG docker `echo $USER`"
    ]
  }
}

data "google_dns_managed_zone" "dns_zone" {
  name = "nthings"
}

resource "google_dns_record_set" "dns" {
  name = "rancher.${data.google_dns_managed_zone.dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${data.google_dns_managed_zone.dns_zone.name}"

  rrdatas = [module.lb.load_balancer_ip_address]
}