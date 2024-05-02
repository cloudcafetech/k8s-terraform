resource "google_compute_instance" "k8srke2-worker-1" {
  depends_on = [
    null_resource.k8srke2-master1-setup,
    null_resource.k8srke2-master2-setup
  ]
  name         = "k8srke2-worker-1"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8srke2-worker-1"

    initialize_params {
      image = var.image["ubuntu"]
      size  = 30
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
  connection {
    type        = "ssh"
    user        = var.user
    host        = google_compute_instance.k8srke2-worker-1.network_interface[0].network_ip
    private_key = file(var.privatekeypath)
  }
  provisioner "file" {
    source      = "./k8setup.sh"
    destination = "./k8setup.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2/",
      "echo 'server: https://${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}:9345\ntoken: ksrkePK\nnode-label:\n- region=worker\n' > config.yaml",
      "sudo mv config.yaml /etc/rancher/rke2/config.yaml",
      "sudo chown root:root /etc/rancher/rke2/config.yaml",
      "chmod +x ./k8setup.sh",
      "sudo sh ./k8setup.sh worker",
    ]
  }
}


resource "google_compute_instance" "k8srke2-worker-2" {
  depends_on = [
    null_resource.k8srke2-master1-setup,
    null_resource.k8srke2-master2-setup
  ]
  name         = "k8srke2-worker-2"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8srke2-worker-2"

    initialize_params {
      image = var.image["ubuntu"]
      size  = 30
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
  connection {
    type        = "ssh"
    user        = var.user
    host        = google_compute_instance.k8srke2-worker-2.network_interface[0].network_ip
    private_key = file(var.privatekeypath)
  }
  provisioner "file" {
    source      = "./k8setup.sh"
    destination = "./k8setup.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2/",
      "echo 'server: https://${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}:9345\ntoken: ksrkePK\nnode-label:\n- region=worker\n' > config.yaml",
      "sudo mv config.yaml /etc/rancher/rke2/config.yaml",
      "sudo chown root:root /etc/rancher/rke2/config.yaml",
      "chmod +x ./k8setup.sh",
      "sudo sh ./k8setup.sh worker",
    ]
  }
}


