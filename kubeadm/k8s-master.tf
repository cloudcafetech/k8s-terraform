resource "google_compute_instance" "k8skube-master-1" {

  name         = "k8skube-master-1"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8skube-master-1"

    initialize_params {
      image = var.image["ubuntu"]
      size  = 40
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

resource "google_compute_instance" "k8skube-master-2" {

  name         = "k8skube-master-2"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8skube-master-2"

    initialize_params {
      image = var.image["ubuntu"]
      size  = 40
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

resource "null_resource" "k8skube-master1-setup" {
    depends_on = [
     google_compute_instance.k8skube-master-1,
     google_compute_instance.k8skube-master-2,
     google_compute_instance.k8s-haproxy-lb,
     null_resource.k8s-haproxy-lb-setup
    ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8skube-master-1.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "file" {
      source      = "./k8setup.sh"
      destination = "k8setup.sh"
    }
    provisioner "remote-exec" {
      inline = [
        "chmod +x ./k8setup.sh",
        "sudo sh ./k8setup.sh k8scommon",
        "sudo kubeadm init --token=hp9b0k.1g9tqz8vkf78ucwf --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint '${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}:6443' --upload-certs --ignore-preflight-errors=all | grep -Ei 'kubeadm join|discovery-token-ca-cert-hash|certificate-key' 2>&1 | tee kubeadm-output.txt",
        "sudo sh ./k8setup.sh master",
        "sudo chown -R k8sgcp:k8sgcp ~/.kube",
        "echo 'export KUBECONFIG=/home/k8sgcp/.kube/config' >> $HOME/.bash_profile",
      ]
    }
    provisioner "local-exec" {
      command = "ansible-playbook -i '${google_compute_instance.k8skube-master-1.network_interface[0].network_ip},' playbook.yml"
    }
}

resource "null_resource" "k8skube-master2-setup" {
  depends_on = [null_resource.k8skube-master1-setup]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8skube-master-2.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "file" {
      source      = "./k8setup.sh"
      destination = "k8setup.sh"
    }
    provisioner "file" {
      source      = "./kubeadm-output.txt"
      destination = "kubeadm-output.txt"
    }
    provisioner "remote-exec" {
      inline = [
        "chmod +x ./k8setup.sh",
        "sudo sh ./k8setup.sh k8scommon",
        "more kubeadm-output.txt | grep certificate-key | sed -n 's/--control-plane --certificate-key//p' > CERTKEY",
        "more kubeadm-output.txt | grep discovery-token-ca-cert-hash | tail -1 | sed -n 's/--discovery-token-ca-cert-hash//p' > HASHKEY",
        "sudo kubeadm join '${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}:6443' --token=hp9b0k.1g9tqz8vkf78ucwf --discovery-token-ca-cert-hash $(cat HASHKEY) --control-plane --certificate-key $(cat CERTKEY) --ignore-preflight-errors=all",
        "sudo sh ./k8setup.sh master",
        "sudo chown -R k8sgcp:k8sgcp ~/.kube",
        "echo 'export KUBECONFIG=/home/k8sgcp/.kube/config' >> $HOME/.bash_profile",
      ]
    }
}