#!/bin/sh

VERSION=v1.29.3+rke2r1
USER=k8sgcp
OP=$(uname -a | grep -iE 'ubuntu|debian')

if [ "$OP" != "" ]; then
 OS=Ubuntu
fi


########################## Common Setup #######################
common() {

echo -  Installing packages
if [ "$OS" = "Ubuntu" ]; then
 systemctl stop ufw
 systemctl stop apparmor.service
 systemctl disable --now ufw
 systemctl disable --now apparmor.service

 apt update -y
 apt-get install -y apt-transport-https ca-certificates gpg nfs-common curl wget git unzip telnet apparmor ldap-utils 
else
 systemctl stop firewalld
 systemctl disable firewalld
 setenforce 0
 sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
 yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet dos2unix java-1.7.0-openjdk
fi

}

####################### Open LDAP Setup #######################
ldapsetup() {

echo -  Open LDAP Setup on [$(hostname)]
common

if [ "$OS" = "Ubuntu" ]; then
 apt update -y
 apt install docker.io ldap-utils -y
 HIP=`ip -o -4 addr list ens4 | awk '{print $4}' | cut -d/ -f1`
else
 yum install docker-ce docker-ce-cli -y
 systemctl start docker
 systemctl enable --now docker
 HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
fi

echo - starting Open LDAP Service
docker run --restart=always --name ldap-server -p 389:389 -p 636:636 \
--env LDAP_TLS_VERIFY_CLIENT=try \
--env LDAP_ORGANISATION="Cloudcafe Org" \
--env LDAP_DOMAIN="cloudcafe.org" \
--env LDAP_ADMIN_PASSWORD="StrongAdminPassw0rd" \
--detach osixia/openldap:latest

echo - Check LDAP Server UP and Running
sleep 10
until [ $(docker inspect -f {{.State.Running}} ldap-server)"=="true ]; do echo "Waiting for LDAP to UP..." && sleep 1; done;

echo - Add LDAP User and Group
wget -q https://raw.githubusercontent.com/cloudcafetech/k8s-ad-integration/main/ldap-records.ldif
ldapadd -x -H ldap://$HIP -D "cn=admin,dc=cloudcafe,dc=org" -w StrongAdminPassw0rd -f ldap-records.ldif

echo - LDAP query for Verify
ldapsearch -x -H ldap://$HIP -D "cn=admin,dc=cloudcafe,dc=org" -b "dc=cloudcafe,dc=org" -w "StrongAdminPassw0rd"

}

######################### web Setup ###########################
websetup() {

echo - Web Server Setup on [$(hostname)]
common

if [ "$OS" = "Ubuntu" ]; then
 apt install apache2 -y
 sed -i 's/Listen 80/Listen 0.0.0.0:8080/' /etc/apache2/ports.conf
 sed -i 's/80/8080/' /etc/apache2/sites-enabled/000-default.conf
 systemctl start apache2
 systemctl enable --now apache2
 systemctl restart apache2
else
 yum install -y httpd
 sed -i 's/Listen 80/Listen 0.0.0.0:8080/' /etc/httpd/conf/httpd.conf
 setsebool -P httpd_read_user_content 1
 systemctl start httpd
 systemctl enable --now httpd
fi 

}

########################## LB Setup ###########################
lbsetup() {

echo - LB Setup on [$(hostname)]
common

if [ "$OS" = "Ubuntu" ]; then
 apt install -y haproxy  
else
 yum install -y haproxy 
fi

#websetup

}

######################## Master Setup #########################
master() {

echo - Setup Master Node
common

echo - Disabling swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo - Setup RKE2 on [$(hostname)]
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION="$VERSION" INSTALL_RKE2_TYPE=server sh -
systemctl start rke2-server.service
systemctl enable --now rke2-server.service

echo - Copying Kubeconfig
cp -f /var/lib/rancher/rke2/agent/etc/crictl.yaml /etc/crictl.yaml
mkdir -p $HOME/.kube
mkdir -p /home/$USER/.kube
cp -f /etc/rancher/rke2/rke2.yaml $HOME/.kube/config
cp -f /etc/rancher/rke2/rke2.yaml /home/$USER/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo 'export PATH=/var/lib/rancher/rke2/bin:$PATH' >> $HOME/.profile
echo 'export KUBECONFIG=$HOME/.kube/config' >> $HOME/.profile
echo 'alias oc=/var/lib/rancher/rke2/bin/kubectl' >> $HOME/.profile
cp -f /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

}

######################## worker Setup #########################
worker() {

echo - Setup Worker Node
common

echo - Disabling swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo - Setup RKE2 on [$(hostname)]
curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION="$VERSION" INSTALL_RKE2_TYPE=agent sh -
systemctl start rke2-agent.service
systemctl enable --now rke2-agent.service

cp -f /var/lib/rancher/rke2/agent/etc/crictl.yaml /etc/crictl.yaml
echo 'export PATH=/var/lib/rancher/rke2/bin:$PATH' >> $HOME/.profile

}

##################### K8s Eco System Setup ####################
k8seco() {

curl -#OL https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/mc

mkdir monitoring
cd monitoring

kubectl create ns minio-store
kubectl create ns logging
kubectl create ns monitoring

echo - Setup Metric Server
curl -#OL https://raw.githubusercontent.com/cloudcafetech/rke2-airgap/main/metric-server.yaml
kubectl create -f metric-server.yaml

echo -  Setup local storage
curl -#OL https://raw.githubusercontent.com/cloudcafetech/rke2-airgap/main/local-path-storage.yaml
kubectl create -f local-path-storage.yaml

echo -  Setup reloader
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-ad-integration/main/reloader.yaml
kubectl create -f reloader.yaml

echo - Setup Monitoring
curl -#OL https://raw.githubusercontent.com/cloudcafetech/AI-for-K8S/main/kubemon.yaml
curl -#OL https://github.com/cloudcafetech/kubesetup/raw/master/monitoring/dashboard/pod-monitoring.json
curl -#OL https://github.com/cloudcafetech/kubesetup/raw/master/monitoring/dashboard/kube-monitoring-overview.json
kubectl create configmap grafana-dashboards -n monitoring --from-file=pod-monitoring.json --from-file=kube-monitoring-overview.json

echo - Setup Logging
curl -#OL https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/logging/promtail.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-ad-integration/main/kubelog.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-ad-integration/main/loki.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/gcp-terraform-rke2/minio.yaml
kubectl create secret generic loki -n logging --from-file=loki.yaml
kubectl create -f kubelog.yaml -n logging
kubectl delete ds loki-fluent-bit-loki -n logging
kubectl wait pods/loki-0 --for=condition=Ready --timeout=2m -n logging

}

############### K8s Eco System Setup using Argo #################
k8secoa() {

curl -#OL https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/mc

kubectl create ns minio-store
kubectl create ns cert-manager
kubectl create ns argocd
kubectl create ns monitoring
kubectl create ns logging
kubectl create ns velero
kubectl create ns argo-backup

echo -  Setup local storage
curl -#OL https://raw.githubusercontent.com/cloudcafetech/rke2-airgap/main/local-path-storage.yaml
kubectl create -f local-path-storage.yaml

echo -  Setup reloader
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-ad-integration/main/reloader.yaml
kubectl create -f reloader.yaml

echo - Setup ArgoCD
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/argo-crd.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/argo-install.yaml
kubectl create -f argo-crd.yaml -n argocd
kubectl create -f argo-install.yaml -n argocd
argopo1=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | head -1`
argopo2=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | tail -1`
kubectl wait pods/$argopo1 --for=condition=Ready --timeout=2m -n argocd
kubectl wait pods/$argopo2 --for=condition=Ready --timeout=2m -n argocd
sleep 30

echo - K8s Addons
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/addon-app.yaml
#kubectl create -f addon-app.yaml -n argocd

echo - Setup MinIO
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/minio-app.yaml
kubectl create -f minio-app.yaml -n argocd
sleep 10
kubectl wait pods/minio-0 --for=condition=Ready --timeout=2m -n minio-store
kubectl wait pods/minio-1 --for=condition=Ready --timeout=2m -n minio-store
kubectl create -f all-ing.yaml
sleep 10
minioing=`kubectl get ing -n minio-store | grep minio-api | awk '{ print $3}'`
mc config host add k8sminio http://$minioing admin admin2675 --insecure
mc mb k8sminio/lokik8sminio --insecure
mc mb k8sminio/promk8sminio --insecure
mc mb k8sminio/velero --insecure
mc mb k8sminio/argo-backup --insecure

echo - Setup Monitoring
curl -#OL https://github.com/cloudcafetech/kubesetup/raw/master/monitoring/dashboard/pod-monitoring.json
curl -#OL https://github.com/cloudcafetech/kubesetup/raw/master/monitoring/dashboard/kube-monitoring-overview.json
kubectl create configmap grafana-dashboards -n monitoring --from-file=pod-monitoring.json --from-file=kube-monitoring-overview.json
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/monitoring-app.yaml
kubectl create -f monitoring-app.yaml -n argocd

echo - Setup Thanos
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/thanos-app.yaml
kubectl create -f thanos-app.yaml -n argocd

echo - Setup Logging
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/rke2/kubedns-svc.yaml  # FiX for loki loki-gateway Nginx pod crashloopback
kubectl create -f kubedns-svc.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/logging-app.yaml
kubectl create -f logging-app.yaml -n argocd

echo - Setup Grafana
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/grafana-app.yaml
kubectl create -f grafana-app.yaml -n argocd

echo - Setup CertManager
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/certmanager-app.yaml
kubectl create -f certmanager-app.yaml -n argocd

echo - Setup Velero
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/velero-app.yaml
kubectl create -f velero-app.yaml -n argocd

echo - Setup Argo Backup
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/argo-backup-app.yaml
kubectl create -f argo-backup-app.yaml -n argocd

}

############## K8s AD/LDAP Integration #################
adauth() {

LBPUBIP=$lbpubip
LBPRIIP=$lbpriip
LDAPIP=$ldapip

mkdir adauth
cd adauth

curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/all-ing.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/ad-enable-ing.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/dex.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/dashboard-ui.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/dex-ldap-cm.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/argocd-cm-ldap.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/oauth-proxy.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/gangway.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/ldap.toml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/minio-ad.yaml
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/read-access.json
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/admin-access.json
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/argo/grafana-ad-app.yaml

sed -i "s/ldap-ip-pri/$LDAPIP/g" *
sed -i "s/lb-ip-pub/$LBPUBIP/g" *
sed -i "s/lb-ip-pri/$LBPRIIP/g" *

kubectl create ns auth-system 
#kubectl create ns kubernetes-dashboard

echo - Delete old Ingress
kubectl delete -f all-ing.yaml

echo - Creating AD enabled Ingress
kubectl create -f ad-enable-ing.yaml

echo - Setup ArgoCD with AD and LDAP
kubectl delete cm argocd-cm argocd-cmd-params-cm argocd-rbac-cm -n argocd
kubectl create -f argocd-cm-ldap.yaml -n argocd
argopo1=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | head -1`
argopo2=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | tail -1`
argopodex1=`kubectl get pod -n argocd | grep dex-server | awk '{print $1}'`
kubectl delete po $argopo1 $argopo2 $argopodex1 -n argocd
sleep 10
argopo1=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | head -1`
argopo2=`kubectl get pod -n argocd | grep argocd-server | awk '{print $1}' | tail -1`
argopodex1=`kubectl get pod -n argocd | grep dex-server | awk '{print $1}'`
kubectl wait pods/$argopo1 --for=condition=Ready --timeout=2m -n argocd
kubectl wait pods/$argopo2 --for=condition=Ready --timeout=2m -n argocd
kubectl wait pods/$argopodex1 --for=condition=Ready --timeout=2m -n argocd
sleep 30

echo - Setup K8s Dashboard
#kubectl get secret dex --namespace=auth-system -oyaml | grep -v '^\s*namespace:\s' | kubectl apply --namespace=kubernetes-dashboard -f -
kubectl apply -f dashboard-ui.yaml

echo - Dex Deployment
kubectl create -f dex-ldap-cm.yaml
kubectl create -f dex.yaml

# Check for Dex POD UP
echo "Waiting for Dex POD ready .."
DEXPOD=$(kubectl get pod -n auth-system | grep dex | awk '{print $1}')
kubectl wait pods/$DEXPOD --for=condition=Ready --timeout=2m -n auth-system

echo - Oauth Deployment
kubectl create -f oauth-proxy.yaml

# Check for OAuth POD UP
echo "Waiting for OAuth POD ready .."
OAPOD=$(kubectl get pod -n auth-system | grep oauth | awk '{print $1}')
kubectl wait pods/$OAPOD --for=condition=Ready --timeout=2m -n auth-system

echo - Gangway Deployment
kubectl create secret generic gangway-key --from-literal=sesssionkey=$(openssl rand -base64 32) -n auth-system
kubectl create -f gangway.yaml

echo - Check for Gangway POD UP
echo "Waiting for Gangway POD ready .."
GWPOD=$(kubectl get pod -n auth-system | grep gangway | awk '{print $1}')
kubectl wait pods/$GWPOD --for=condition=Ready --timeout=2m -n auth-system

echo - Setup MinIO with AD and LDAP
kubectl get secret dex -n auth-system -o jsonpath="{['data']['ca\.crt']}" | base64 --decode >ca.crt
kubectl create cm dex-cert --from-file=ca.crt -n minio-store
kubectl delete app minio -n argocd
sleep 20
kubectl delete -f minio-ad.yaml -n minio-store
sleep 10
kubectl create -f minio-ad.yaml -n minio-store
sleep 10
kubectl wait pods/minio-0 --for=condition=Ready --timeout=2m -n minio-store
kubectl wait pods/minio-1 --for=condition=Ready --timeout=2m -n minio-store
sleep 10
mc admin policy create k8sminio admins admin-access.json
mc admin policy create k8sminio developers read-access.json

# Monitoring login (LDAP) enablement
kubectl delete app grafana -n argocd
sleep 20
kubectl create secret generic grafana-ldap-toml --from-file=ldap.toml=./ldap.toml -n monitoring
kubectl create -f grafana-ad-app.yaml -n argocd

# Check for Grafana POD UP and Running
echo "Waiting for Grafana POD UP and Running without Error .."
GFPOD=$(kubectl get pod -n monitoring | grep grafana | awk '{print $1}')
kubectl wait pods/$GFPOD --for=condition=Ready --timeout=2m -n monitoring

# Creating AD enable user RBAC
kubectl create clusterrolebinding debrupkar-view --clusterrole=view --user=debrupkar@cloudcafe.org 
kubectl create clusterrolebinding prasenkar-admin --clusterrole=admin --user=prasenkar@cloudcafe.org
kubectl create rolebinding titli-view-default --clusterrole=view --user=titlikar@cloudcafe.org -n default
kubectl create rolebinding rajat-admin-default --clusterrole=admin --user=rajatkar@cloudcafe.org -n default

}

####### Copy Certificate and edit the Kubernetes API configuration ##########
apialter () {

LBPUBIP=$lbpubip

echo - Copy Certificate and edit the Kubernetes API configuration for RKE2
kubectl get secret dex -n auth-system -o jsonpath="{['data']['ca\.crt']}" | base64 --decode >ca.crt
curl -#OL https://raw.githubusercontent.com/cloudcafetech/k8s-terraform/master/ad-ldap/add-line-rke2.txt
sed -i "s/lb-ip-pub/$LBPUBIP/g" add-line-rke2.txt
sudo cp ca.crt /var/lib/rancher/rke2/server/tls/dex-ca.crt
sudo sed -i '/rke2-snapshot-validation-webhook/r add-line-rke2.txt' /etc/rancher/rke2/config.yaml
sudo systemctl restart rke2-server.service
}

########################### usage #############################
usage () {
  echo ""
  echo " Usage: $0 {lbsetup | websetup | master | worker | k8seco}"
  echo ""
  echo " $0 lbsetup # Setup LB (HAPROXY) Server"
  echo ""
  echo " $0 websetup # Setup Http (Apache) Server"
  echo ""
  echo " $0 master # Setup Master Node"
  echo ""
  echo " $0 worker # Setup Worker Node"
  echo ""
  echo " $0 k8seco # Setup K8s Eco System"
  echo ""
  exit 1
}

case "$1" in
        lbsetup ) lbsetup;;
        ldapsetup ) ldapsetup;;
        websetup ) websetup;;
        master ) master;;
        worker ) worker;;
        k8seco ) k8seco;;
        k8secoa ) k8secoa;;  
        adauth ) adauth;;
        apialter ) apialter;;    
        *) usage;;
esac
