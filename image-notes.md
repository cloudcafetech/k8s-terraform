## Image save


podman save --output registry.tar docker.io/library/registry:latest 

ctr -a /var/run/containerd/containerd.sock namespace ls

ctr -a /var/run/containerd/containerd.sock --namespace k8s.io image import --base-name docker.io/library/registry:latest registry.tar


while IFS= read -r img; do
    echo "Text read from file: $img"
done < quay.txt

while IFS= read -r img; do  
  IMG=`echo $img | cut -d "/" -f3 | cut -d ":" -f1`
  podman pull $img
  podman save --output "$IMG".tar $img
  tar --zstd -cvf images/"$IMG".tar.zst "$IMG".tar
done < quay.txt

tar cf - quay-images/ | zstd > quay-images.tar.zst

tar --zstd -cvf directory.tar.zst directory

tar --zstd -cvf registry.tar.zst registry.tar

```
k8s.gcr.io/addon-resizer:1.7
docker.io/grafana/fluent-bit-plugin-loki:main-e2ed1c0
docker.io/grafana/loki:3.0.0
docker.io/grafana/loki-canary:3.0.0
docker.io/grafana/promtail:2.8.3
docker.io/grafana/grafana:8.5.13
docker.io/kiwigrid/k8s-sidecar:1.24.3
docker.io/nginxinc/nginx-unprivileged:1.24-alpine
docker.io/prom/memcached-exporter:v0.14.2
registry.k8s.io/ingress-nginx/controller:v1.8.2@sha256:74834d3d25b336b62cabeb8bf7f1d788706e2cf1cfd64022de4137ade8881ff2
registry.k8s.io/ingress-nginx/controller:v1.8.1@sha256:e5c4824e7375fcf2a393e1c03c293b69759af37a9ca6abdb91b13d78a93da8bd
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407@sha256:543c40fd093964bc9ab509d3e791f9989963021f1e9e4c9c7b6700b02bfb227b
ghcr.io/stakater/reloader:v1.0.69
docker.io/bitnami/sealed-secrets-controller:0.26.3
docker.io/rancher/local-path-provisioner:v0.0.24
docker.io/busybox:latest
```
