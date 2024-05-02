resource "google_compute_instance" "k8srke2-master-1" {

  name         = "k8srke2-master-1"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8srke2-master-1"

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

resource "google_compute_instance" "k8srke2-master-2" {

  name         = "k8srke2-master-2"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server", "https-server"]
  boot_disk {
    auto_delete = true
    device_name = "k8srke2-master-2"

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

resource "null_resource" "k8srke2-master1-setup" {
    depends_on = [
     google_compute_instance.k8srke2-master-1,
     google_compute_instance.k8srke2-master-2,
     google_compute_instance.k8s-haproxy-lb
    ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-1.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "file" {
      source      = "./k8setup.sh"
      destination = "k8setup.sh"
    }
    provisioner "remote-exec" {
      inline = [
        "sudo mkdir -p /etc/rancher/rke2/",
        "echo 'token: ksrkePK\nwrite-kubeconfig-mode: 0644\ncluster-cidr: 192.168.0.0/16\nservice-cidr: 192.167.0.0/16\nnode-label:\n- region=master\ntls-san:\n  - ${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}\n  - ${google_compute_instance.k8srke2-master-2.network_interface[0].network_ip}\n  - ${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}\n  - k8s-haproxy-lb\n  - k8srke2-master-1\n  - k8srke2-master-2\ndisable:\n  - rke2-snapshot-controller\n  - rke2-snapshot-controller-crd\n  - rke2-snapshot-validation-webhook\n' > config.yaml",
        "sudo mv config.yaml /etc/rancher/rke2/config.yaml",
        "sudo chown root:root /etc/rancher/rke2/config.yaml",
        "chmod +x ./k8setup.sh",
        "sudo sh ./k8setup.sh master",
        "sudo chown -R k8sgcp:k8sgcp ~/.kube",
        "echo 'export PATH=/var/lib/rancher/rke2/bin:$PATH' >> $HOME/.bash_profile",
        "echo 'export KUBECONFIG=/home/k8sgcp/.kube/config' >> $HOME/.bash_profile",
      ]
    }
}

resource "null_resource" "k8srke2-master2-setup" {
  depends_on = [null_resource.k8srke2-master1-setup]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-2.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "file" {
      source      = "./k8setup.sh"
      destination = "k8setup.sh"
    }
    provisioner "remote-exec" {
      inline = [
        "sudo mkdir -p /etc/rancher/rke2/",
        "echo 'server: https://${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}:9345\ntoken: ksrkePK\nwrite-kubeconfig-mode: 0644\ncluster-cidr: 192.168.0.0/16\nservice-cidr: 192.167.0.0/16\nnode-label:\n- region=master\ntls-san:\n  - ${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip}\n  - ${google_compute_instance.k8srke2-master-2.network_interface[0].network_ip}\n  - ${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}\n  - k8s-haproxy-lb\n  - k8srke2-master-1\n  - k8srke2-master-2\n' > config.yaml",
        "sudo mv config.yaml /etc/rancher/rke2/config.yaml",
        "sudo chown root:root /etc/rancher/rke2/config.yaml",
        "chmod +x ./k8setup.sh",
        "sudo sh ./k8setup.sh master",
        "sudo chown -R k8sgcp:k8sgcp ~/.kube",
        "echo 'export PATH=/var/lib/rancher/rke2/bin:$PATH' >> $HOME/.bash_profile",
        "echo 'export KUBECONFIG=/home/k8sgcp/.kube/config' >> $HOME/.bash_profile",
    ]
  }
}