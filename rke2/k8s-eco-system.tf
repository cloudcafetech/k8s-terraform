resource "null_resource" "k8s-ecosystem-setup" {
    depends_on = [
      null_resource.k8srke2-master1-setup,
      null_resource.k8srke2-master2-setup,
      null_resource.k8s-haproxy-lb-setup
    ]
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.k8srke2-master-1.network_interface[0].network_ip
      private_key = file(var.privatekeypath)
    }
    provisioner "remote-exec" {
      inline = [
        "curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/all-ing.yaml",
        "sed -i 's:34.125.24.130:${google_compute_instance.k8s-haproxy-lb.network_interface[0].access_config[0].nat_ip}:g' all-ing.yaml",
        "sed -i 's:1.2.3.4:${google_compute_instance.k8s-haproxy-lb.network_interface[0].network_ip}:g' all-ing.yaml",
        "sh ./k8setup.sh k8secoa",
      ]
    }
    provisioner "local-exec" {
      command = "ansible-playbook -i '${google_compute_instance.k8srke2-master-1.network_interface[0].network_ip},' playbook.yml"
    }
}
