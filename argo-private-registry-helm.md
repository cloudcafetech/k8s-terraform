## Setup ArgoCD with Private Registry & Helm

- Generate selfsign certificate

```
cat <<EOF > san.cnf
[req]
default_bits  = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = IN
stateOrProvinceName = WB
localityName = KOL
organizationName = Cloud Cafe
commonName = 127.0.0.1: Cloud Cafe

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = controlplane
DNS.2 = localhost
IP.1 = 172.30.1.2
IP.2 = 127.0.0.1
EOF

openssl genrsa 1024 > domain.key
chmod 400 domain.key
openssl req -new -x509 -nodes -sha1 -days 365 -key domain.key -out domain.crt -config san.cnf
```

- Download crane tool

```
curl -sL "https://github.com/google/go-containerregistry/releases/download/v0.19.0/go-containerregistry_Linux_x86_64.tar.gz" > go-containerregistry.tar.gz
tar -zxvf go-containerregistry.tar.gz -C /usr/local/bin/ crane
```

- Setup Private Registry

```
mkdir -p /root/registry/data/auth
mkdir -p /root/registry/data/certs

touch /root/registry/data/auth/htpasswd

docker run --name htpass --entrypoint htpasswd httpd:2 -Bbn admin admin@2675 > /root/registry/data/auth/htpasswd  
docker rm htpass

cp domain.* /root/registry/data/certs/
docker run -itd -p 5000:5000 --restart=always --name private-registry \
 -v /root/registry/data/auth:/auth -v /root/registry/data:/var/lib/registry \
 -v /root/registry/data/certs:/certs -v /root/registry/data/certs:/certs \
 -e REGISTRY_AUTH=htpasswd -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry
```

- Add entry in daemon jason for insecure registries
```
cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2",
  "insecure-registries" : ["172.30.1.2:5000"],
  "registry-mirrors": ["https://mirror.gcr.io","https://docker-mirror.killercoda.com","https://docker-mirror.killer.sh"],
  "mtu": 1454
}
EOF
systemctl restart docker
```

- Upload images in Private registries

```
docker login -u admin -p admin@2675 172.30.1.2:5000

crane --insecure copy quay.io/jetstack/cert-manager-acmesolver:v1.13.3 172.30.1.2:5000/jetstack/cert-manager-acmesolver:v1.13.3
crane --insecure copy quay.io/jetstack/cert-manager-cainjector:v1.13.3 172.30.1.2:5000/jetstack/cert-manager-cainjector:v1.13.3
crane --insecure copy quay.io/jetstack/cert-manager-controller:v1.13.3 172.30.1.2:5000/jetstack/cert-manager-controller:v1.13.3
crane --insecure copy quay.io/jetstack/cert-manager-webhook:v1.13.3 172.30.1.2:5000/jetstack/cert-manager-webhook:v1.13.3
crane --insecure copy quay.io/jetstack/cert-manager-ctl:v1.13.3 172.30.1.2:5000/jetstack/cert-manager-ctl:v1.13.3
```

- Setup ArgoCD

```
wget -q https://raw.githubusercontent.com/cloudcafetech/k8sdemo/main/argo.yaml
kubectl create ns argocd
kubectl create -f argo.yaml -n argocd

kubectl wait po -l app.kubernetes.io/name=argocd-server --for=condition=Ready --timeout=5m -n argocd
argopass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $argopass
```

- Get Auth from docker

``` cat /root/.docker/config.json ```

- Modify containerd config.toml file for private registry as below example

```
vi /etc/containerd/config.toml

systemctl restart containerd
```

- example 

```
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.auths]

      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."172.30.1.2:5000".tls]
          insecure_skip_verify = true
      [plugins."io.containerd.grpc.v1.cri".registry.configs."172.30.1.2:5000".auth]
          auth = "YWRtaW46YWRtaW5AMjY3NQ=="
      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://172.30.1.2:5000", "https://mirror.gcr.io", "https://docker-mirror.killercoda.com", "https://docker-mirror.killer.sh", "https://registry-1.docker.io"]
```

- Deply Argo app

```
cat > cert-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  destination:
    namespace: cert-manager
    server: 'https://kubernetes.default.svc'
  source:
    path: cert-manager
    repoURL: 'https://github.com/cloudcafetech/k8sdemo'
    targetRevision: HEAD
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
kubectl create -f cert-app.yaml
```

- Extract images from helm template

```
CERT_VERSION=v1.13.3
helm repo add jetstack https://charts.jetstack.io --force-update
helm pull jetstack/cert-manager --version "$CERT_VERSION"
helm template cert-manager-"$CERT_VERSION".tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g > cert-manager-images.txt
```

- Prapare Sub Chart file

```
cat > Chart.yaml << EOF
apiVersion: v2
name: cert-manager
description: A Helm chart for cert-manager
type: application
version: 0.1
appVersion: v1.13.3
dependencies:
  - name: cert-manager
    version: v1.13.3
    repository: https://raw.githubusercontent.com/cloudcafetech/k8sdemo/refs/heads/main/cert-manager
EOF
```

- Prapare Index file

```
cat > index.yaml << EOF
apiVersion: v1
entries:
  cert-manager:
  - apiVersion: v1
    appVersion: v1.13.3
    description: A Helm chart for cert-manager
    name: cert-manager
    urls:
    - https://raw.githubusercontent.com/cloudcafetech/k8sdemo/refs/heads/main/cert-manager/cert-manager-v1.13.3.tgz
    version: v1.13.3
EOF
```

- Prapare values.yaml file

```
cert-manager:
  installCRDs: true
  replicaCount: 1
  image:
    repository: 172.30.1.2:5000/jetstack/cert-manager-controller
    pullPolicy: IfNotPresent
  webhook:
    image:
      repository: 172.30.1.2:5000/jetstack/cert-manager-webhook
  cainjector:
    image:
      repository: 172.30.1.2:5000/jetstack/cert-manager-cainjector
  acmesolver:
    image:
      repository: 172.30.1.2:5000/jetstack/cert-manager-acmesolver
  startupapicheck:
    image:
      repository: 172.30.1.2:5000/jetstack/cert-manager-ctl
```

- Upload index,chart,values yaml & helm package .tgz files in Git repo
