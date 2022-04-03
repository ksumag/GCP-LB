terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.9.0"
    }
    
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
        
    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }
  }
}
provider "local" {
  # Configuration options
}

provider "google" {
  credentials = "${file("key.json")}"
  project     = var.project_id
  region      = var.gregion
}

provider "aws" {
  region     = var.region
  access_key = var.my-access-key
  secret_key = var.my-secret-key
}

//ssh
data "google_client_openid_userinfo" "me" {
}

resource "google_os_login_ssh_public_key" "cache" {
  user =  data.google_client_openid_userinfo.me.email
  key  = file(var.pubkey)
}

//create application servers
resource "google_compute_instance" "application_server" {
  name         = "${element(var.apps, count.index)}"
  count        = local.APS_quantity
  tags         = ["devops", "ansible13"]
  machine_type = "f1-micro"
  zone         = var.gregion
  boot_disk {
   initialize_params {
     image = "ubuntu-os-cloud/ubuntu-1804-lts"
   }
  }
  network_interface {
    network = "default"
    access_config {
      
    }
  }
  metadata = {
    ssh-keys = "root:${file(var.pubkey)}"
  }
}


locals {
  
  //LB_quantity = "${length(var.lb)}"
  APS_quantity = "${length(var.apps)}"
  
}

resource "google_compute_http_health_check" "alive" {
    name               = "alive-check"
    request_path       = "/"
    port               = 80
    check_interval_sec = 10
    timeout_sec        = 4
}

resource "google_compute_target_pool" "instance-group" {
    name             = "balance-instance-group"
    session_affinity = "NONE"
    region           = "europe-west3"

    instances =  "${google_compute_instance.application_server.*.self_link}"

    health_checks = [
        "${google_compute_http_health_check.alive.name}"
    ]
}

resource "google_compute_address" "lb-adr" {
  //provider      = google-beta
  name          = "lbadress-for-dns"
  region        = "europe-west3"
  
}
resource "google_compute_firewall" "rules" {
  name        = "allow-http-for-nginx"
  network     = "default"
  description = "Creates firewall rule targeting tagged instances"

  allow {
    protocol  = "tcp"
    ports     = ["80", "8080"]
  }
  source_ranges = ["0.0.0.0/0"] 
  target_tags = ["devops", "ansible13"]
}
resource "google_compute_forwarding_rule" "load-balancer" {
    name                  = "djamshut"
    region                = "europe-west3"
    target                = "${google_compute_target_pool.instance-group.self_link}"
    ip_address            = "${google_compute_address.lb-adr.id}"
    port_range            = "80"
    ip_protocol           = "TCP"
    load_balancing_scheme = "EXTERNAL"
}
//getting external IP value
  data "google_compute_address" "static_IP" {
  name       = "lbadress-for-dns"
  region     = "europe-west3"
  depends_on = [
    google_compute_address.lb-adr
  ]
}


  data "aws_route53_zone" "primary" {
  name = "devops.rebrain.srwx.net"
  
}

resource "aws_route53_record" "APP_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${element(var.apps, count.index)}.${data.aws_route53_zone.primary.name}"
  count   = local.APS_quantity
  type    = "A"
  ttl     = "300"
  records = [google_compute_instance.application_server[count.index].network_interface.0.access_config.0.nat_ip]
}

resource "aws_route53_record" "LB_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "ksumag.${data.aws_route53_zone.primary.name}"
  type    = "A"
  ttl     = "300"
  records = [data.google_compute_address.static_IP.address]
    depends_on = [
    google_compute_address.lb-adr,
    data.google_compute_address.static_IP
  ]
}


resource "local_file" "inventory_1" {
    content     = templatefile("${path.module}/inventory.tpl", { 
                           
                          access_key = var.my_private,
                          ip_app = "${google_compute_instance.application_server.*.network_interface.0.access_config.0.nat_ip}",
                          name_app = aws_route53_record.APP_record.*.name,
                          APP_servers = var.apps 
                          
      })
    filename = "${path.module}/inventory_1.yml"
}

resource "null_resource" "Ansible_run" {
  provisioner "local-exec" {
    command = "sleep 60 && ansible-playbook -i inventory_1.yml playbook_1.yml " 
 }
  depends_on = [
    google_compute_address.lb-adr,
    data.google_compute_address.static_IP,
    aws_route53_record.LB_record,
    aws_route53_record.APP_record,
    local_file.inventory_1
  ]
}
    
  