resource "google_compute_instance" "k8s-haproxy-lb" {

  name         = "k8s-haproxy-lb"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8s-haproxy-lb"

    initialize_params {
      image = var.image["ubuntu"]
      size  = 20
      type  = "pd-balanced"
    }
  }
  network_interface {
    network = "default"
    access_config {

    }
  }
  metadata = {
    ssh-keys = "${var.user}:${file(var.publickeypath)}"
  }
}

resource "null_resource" "k8s-haproxy-lb-setup" {
    depends_on = [
      null_resource.k8srke2-master1-setup,
      null_resource.k8srke2-master2-setup
    ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "file" {
      source      = "./k8setup.sh"
      destination = "k8setup.sh"
    }
    provisioner "file" {
      source      = "./haproxy.cfg"
      destination = "haproxy.cfg"
    }
    provisioner "remote-exec" {
      inline = [
        "chmod +x ./k8setup.sh",
        "sudo sh ./k8setup.sh lbsetup",
        "#curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/rke2/haproxy.cfg",
        "sed -i -e 's:VMDNS1:k8srke2-master-1:g' -e 's:VMDNS2:k8srke2-master-2:g' -e 's:VMIP1:${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}:g' -e 's:VMIP2:${google_compute_instance.k8srke2-master-2.network_interface[0].network_ip}:g' haproxy.cfg",
        "sed -i '/VMDNS3/d' haproxy.cfg",
        "sudo mv haproxy.cfg /etc/haproxy/haproxy.cfg",
        "sudo chown root:root /etc/haproxy/haproxy.cfg",
        "sudo systemctl restart haproxy",
        "#sudo sh ./k8setup.sh ldapsetup",
    ]
  }
}
