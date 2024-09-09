- Create self signed root CA

```
cat << EOF > root-ca.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca-issuer-selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: cloudcafe
  secretName: root-ca-secret
  duration: 87600h # 10y
  renewBefore: 78840h # 9y
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: root-ca-issuer-selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: root-ca-issuer
spec:
  ca:
    secretName: root-ca-secret
EOF
kubectl create -f root-ca.yaml
```

- Create the intermediate CA

```
cat << EOF > intermediate-ca.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: intermediate-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: cloudcafe
  secretName: intermediate-ca-secret
  duration: 43800h # 5y
  renewBefore: 35040h # 4y
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: root-ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: intermediate-ca-issuer
spec:
  ca:
    secretName: intermediate-ca-secret
EOF
kubectl create -f intermediate-ca.yaml
```

- Testing

```
kubectl get secret root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' |  base64 -d | openssl x509 -noout -text
kubectl get secret intermediate-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' |  base64 -d | openssl x509 -noout -text
```

- Verify intermediate CA was actually signed by the Root CA

```
openssl verify -CAfile <(kubectl -n cert-manager get secret root-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d) <(kubectl -n cert-manager get secret intermediate-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d)
```

[REF](https://raymii.org/s/tutorials/Self_signed_Root_CA_in_Kubernetes_with_k3s_cert-manager_and_traefik.html)
