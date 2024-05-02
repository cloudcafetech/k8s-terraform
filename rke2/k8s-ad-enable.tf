resource "null_resource" "k8s-ad-ldap-integration" {
    depends_on = [
      null_resource.k8srke2-master1-setup,
      null_resource.k8srke2-master2-setup,
      null_resource.k8s-haproxy-lb-setup,
      google_compute_instance.k8srke2-worker-1,
      google_compute_instance.k8srke2-worker-2
    ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-1.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "remote-exec" {
      inline = [
        "export lbpubip=${google_compute_instance.k8s-haproxy-lb.network_interface[0].access_config[0].nat_ip}",
        "export lbpriip=${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}",
        "export ldapip=${var.ldapip}",
        "#export ldapip=${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}",
        "sh ./k8setup.sh adauth",
      ]
    }
}

resource "null_resource" "k8s-api-alter-master1" {
    depends_on = [ null_resource.k8s-ad-ldap-integration ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-1.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "remote-exec" {
      inline = [
        "export lbpubip=${google_compute_instance.k8s-haproxy-lb.network_interface[0].access_config[0].nat_ip}",
        "sh ./k8setup.sh apialter",
      ]
    }
}

resource "null_resource" "k8s-api-alter-master2" {
    depends_on = [ null_resource.k8s-ad-ldap-integration ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-2.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "remote-exec" {
      inline = [
        "export lbpubip=${google_compute_instance.k8s-haproxy-lb.network_interface[0].access_config[0].nat_ip}",
        "sh ./k8setup.sh apialter",
      ]
    }
}