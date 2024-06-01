## Argocd Installation

```
git clone https://github.com/cloudcafetech/k8s-terraform
cd k8s-terraform/argo
kubectl create ns argocd
kubectl create -f argo-crd.yaml -n argocd
kubectl create -f argo-install.yaml -n argocd
argopo1=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | head -1`
argopo2=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | tail -1`
kubectl wait pods/$argopo1 --for=condition=Ready --timeout=2m -n argocd
kubectl wait pods/$argopo2 --for=condition=Ready --timeout=2m -n argocd

```

## Inside pod

```
kubectl exec -it $argopo1 -n argocd -- git clone https://github.com/cloudcafetech/k8s-terraform
kubectl exec -it $argopo2 -n argocd -- git clone https://github.com/cloudcafetech/k8s-terraform

mkdir /tmp/k8s-terraform
cd /tmp/k8s-terraform
git init
cp -rf /home/argocd/k8s-terraform/* .
git add .
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git commit -m "initial commit"

```

## Argocd CLI

```
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
argopass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo y | argocd login 172.30.1.2:31080 --username admin --password $argopass
```

## Argocd without CLI

```
kubectl create -f minio-app.yaml -n argocd
kubectl create -f logging-app.yaml -n argocd
kubectl create -f monitoring-app.yaml -n argocd
kubectl create -f thanos-app.yaml -n argocd
```

## Argocd apps Status

```kubectl get apps -n argocd```

## Argocd apps DELETE [Ref](https://github.com/argoproj/argo-cd/issues/12493#issuecomment-1433310845)

```kubectl patch apps/velero -n argocd --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'```

## Delete terminating namespace

```NS=`kubectl get ns |grep Terminating | awk 'NR==1 {print $1}'` && kubectl get namespace "$NS" -o json   | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"   | kubectl replace --raw /api/v1/namespaces/$NS/finalize -f -```

## Velero CLI

```
wget -q https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz
tar -zxvf velero-v1.13.0-linux-amd64.tar.gz
mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/
rm -rf velero-*.gz
```

## Velero Deleting Backups
Use the following commands to delete Velero backups and data:

- Delete the backup custom resource only and will not delete any associated data from object/block storage
  
  ```kubectl delete backup <backupName> -n velero``` 

- Delete the backup resource including all data in object/block storage
  
  ```velero backup delete <backupName>```

## Velero resource list

```kubectl api-resources --namespaced=true | grep velero.io```

## Seal Secret

- Using own keys

```
openssl req -x509 -nodes -newkey rsa:4096 -keyout $sstls.key -out $sstls.crt -subj "/CN=sealed-secret/O=sealed-secret"
kubectl create secret tls sealed-secrets-key --cert=$sstls.crt --key=$sstls.key -n kube-system
kubectl label secret -n kube-system sealed-secrets-key sealedsecrets.bitnami.com/sealed-secrets-key=active
```

- Installation

```
wget -q https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.3/controller.yaml
sed -i 's/args: [[]]/args:/g' controller.yaml
sed -i '/args/a --key-renew-period=0' controller.yaml
sed -i 's/--key-renew-period=0/        - --key-renew-period=0/' controller.yaml
```

- Backup

  ```kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > backup-sealedSecret.key```

- Recovery

  ```kubeseal --recovery-unseal -f mysecret-sealed.yaml --recovery-private-key backup-sealedSecret.key -o yaml```

- Client tool (kubeseal)
```
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.23.1/kubeseal-0.23.1-linux-amd64.tar.gz
tar -xvzf kubeseal-0.23.1-linux-amd64.tar.gz kubeseal
install -m 755 kubeseal /usr/local/bin/kubeseal
rm -rf kubeseal*

kubectl get pods -n kube-system | grep sealed-secrets-controller
kubeseal --fetch-cert > public-key-cert.pem
```
- Seal Secret Uses 

```kubeseal --format=yaml --cert=public-key-cert.pem < secret-file-name.yaml > sealed-secret-name.yaml```

## Utilization as per NS

```
NS=( $(kubectl get ns | grep -v NAME | awk '{ print $1}') )
for i in "${NS[@]}"
do
   OP=`kubectl top pods -n "$i" | awk 'BEGIN {mem=0; cpu=0} {mem += int($3); cpu += int($2);} END {print " Memory: " mem "Mi" " " "Cpu: " cpu "m"}'`
   echo "[ $i ] - $OP"
done
```

```
NAMESPACE=logging
echo -e "Pod\tContainer\tlim.cpu\tlim.mem\treq.cpu\treq.mem"
echo -e "---\t---------\t-------\t-------\t-------\t-------"
kubectl get pods -n $NAMESPACE | sed '1d' | awk '{print $1}' | sort | while read POD; do
  kubectl get pod $POD -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}{"'$POD'"}{"\t"}{.name}{"\t"}--{.resources.limits.cpu}{"\t"}--{.resources.limits.memory}{"\t"}--{.resources.requests.cpu}{"\t"}--{.resources.requests.memory}{"\n"}{end}' | sed -E -e 's/--([0-9])/\1/g' -e 's/--/-/g'
done
```
