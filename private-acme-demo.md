## DEMO Private ACME in K8S

- Install Private ACME Server

```
wget https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/main/private-acme.sh
chmod 755 private-acme.sh
./private-acme.sh
```

- Install Ngingx Ingress

```
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm upgrade --install ingress-nginx ingress-nginx --set controller.hostNetwork=true \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace
```

- Install Cert Manager

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade cert-manager jetstack/cert-manager \
    --install \
    --create-namespace \
    --wait \
    --namespace cert-manager \
    --set installCRDs=true

kubectl -n cert-manager get all
kubectl api-resources --api-group=cert-manager.io
```

- Create Cluster Issuer

```
CAB=$(cat /etc/step-ca/certs/root_ca.crt | base64 -w0)

cat << EOF > pcu.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: private-ca
spec:
  acme:
    server: https://172.30.1.2:8443/acme/acme/directory
    #skipTLSVerify: true
    caBundle: $CAB
    privateKeySecretRef:
      name: private-ca
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

kubectl create -f pcu.yaml
```

- Sample app

```
PHIP=$(kubectl get po -n ingress-nginx -o wide | grep ing | awk '{ print $6}')
cat << EOF > sample.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kuard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuard
  namespace: kuard
spec:
  selector:
    matchLabels:
      app: kuard
  replicas: 1
  template:
    metadata:
      labels:
        app: kuard
    spec:
      containers:
      - image: gcr.io/kuar-demo/kuard-amd64:1
        imagePullPolicy: Always
        name: kuard
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kuard
  namespace: kuard
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: kuard
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kuard
  namespace: kuard 
  annotations:
    cert-manager.io/cluster-issuer: "private-ca"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - kuard.$PHIP.nip.io
    secretName: kuard.tls
  rules:
  - host: kuard.$PHIP.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kuard
            port:
              number: 80
EOF

kubectl create -f sample.yaml
```

- Verify

```
kubectl get secret kuard.tls -n kuard -o "jsonpath={.data['tls\.crt']}" | base64 -d | openssl x509 -issuer -noout
kubectl get secret kuard.tls -n kuard -o "jsonpath={.data['tls\.crt']}" | base64 -d | openssl x509 -text -noout
kubectl get secret kuard.tls -n kuard -o "jsonpath={.data['tls\.crt']}" | base64 -d | openssl x509 -dates -noout
kubectl get secret kuard.tls -n kuard -o "jsonpath={.data['tls\.crt']}" | base64 -d | openssl x509 -enddate -noout
```
