resource "google_compute_instance" "k8skube-worker-1" {
  depends_on = [
    null_resource.k8skube-master1-setup,
    null_resource.k8skube-master2-setup
  ]
  name         = "k8skube-worker-1"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8skube-worker-1"

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
    host        = google_compute_instance.k8skube-worker-1.network_interface[0].network_ip
    private_key = file(var.privatekeypath)
  }
  provisioner "file" {
    source      = "./k8setup.sh"
    destination = "./k8setup.sh"
  }
  provisioner "file" {
    source      = "./kubeadm-output.txt"
    destination = "kubeadm-output.txt"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ./k8setup.sh",
      "sudo sh ./k8setup.sh k8scommon",
      "more kubeadm-output.txt | grep discovery-token-ca-cert-hash | tail -1 | sed -n 's/--discovery-token-ca-cert-hash//p' > HASHKEY",
      "sudo kubeadm join '${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}:6443' --token hp9b0k.1g9tqz8vkf78ucwf --discovery-token-ca-cert-hash $(cat HASHKEY) --ignore-preflight-errors=all",
    ]
  }
}

resource "google_compute_instance" "k8skube-worker-2" {
  depends_on = [
    null_resource.k8skube-master1-setup,
    null_resource.k8skube-master2-setup
  ]
  name         = "k8skube-worker-2"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8skube-worker-2"

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
    host        = google_compute_instance.k8skube-worker-2.network_interface[0].network_ip
    private_key = file(var.privatekeypath)
  }
  provisioner "file" {
    source      = "./k8setup.sh"
    destination = "./k8setup.sh"
  }
  provisioner "file" {
    source      = "./kubeadm-output.txt"
    destination = "kubeadm-output.txt"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ./k8setup.sh",
      "sudo sh ./k8setup.sh k8scommon",
      "more kubeadm-output.txt | grep discovery-token-ca-cert-hash | tail -1 | sed -n 's/--discovery-token-ca-cert-hash//p' > HASHKEY",
      "sudo kubeadm join '${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}:6443' --token hp9b0k.1g9tqz8vkf78ucwf --discovery-token-ca-cert-hash $(cat HASHKEY) --ignore-preflight-errors=all",
    ]
  }
}
