#!/bin/bash
# Setup Private ACME server 
# REF1 (https://4sysops.com/archives/step-ca-running-your-own-certificate-authority-with-acme-support/)
# Ref2 (https://blog.bella.network/internal-acme-server/)

# Installing step-ca

CANM=Cloudcafe
PASS=admin2675
HIP=`ip -o -4 addr list enp1s0 | awk '{print $4}' | cut -d/ -f1`
EM=aaa@gmail.com
CA_PORT=8443

HN=$(hostname -f)
mkdir /etc/step-ca
echo $PASS > /etc/step-ca/password.txt

if [[ -n $(uname -a | grep -iE 'ubuntu|debian') ]]; then 
 wget https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.deb
 wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb
 sudo dpkg -i step-cli_amd64.deb step-ca_amd64.deb
 rm -rf step*amd64.deb
else 
 wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.rpm
 wget https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.rpm
 sudo rpm -i step-ca_amd64.rpm step-cli_amd64.rpm
 rm -rf step*amd64.rpm
fi

# Initializing step-ca

#step ca init --deployment-type=standalone --name=$CANM --dns=$HN --address=$HIP:$CA_PORT  --with-ca-url="https://$HIP:$CA_PORT" --provisioner=$EM --password-file=/etc/step-ca/password.txt
step ca init --deployment-type=standalone --name=$CANM --dns=$HIP --dns=$HN --address=$HIP:$CA_PORT  --provisioner=$EM --password-file=/etc/step-ca/password.txt
sleep 5

# Configuration of Step-ca

step ca provisioner add acme --type ACME
sudo useradd --system --home /etc/step-ca --shell /bin/false step
sudo mv $(step path)/* /etc/step-ca
sed -i "s|Step Online CA|$CANM|g" /etc/step-ca/config/ca.json
sed -i "s|root/.step|etc/step-ca|g" /etc/step-ca/config/ca.json
sed -i "s|root/.step|etc/step-ca|g" /etc/step-ca/config/defaults.json
sudo chown -R step:step /etc/step-ca

# Service Step-ca

cat << EOF > /etc/systemd/system/step-ca.service
[Unit]
Description=step-ca service
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=30
StartLimitBurst=3
ConditionFileNotEmpty=/etc/step-ca/config/ca.json
ConditionFileNotEmpty=/etc/step-ca/password.txt

[Service]
Type=simple
User=step
Group=step
Environment=STEPPATH=/etc/step-ca
Environment=CA_PORT=$CA_PORT
WorkingDirectory=/etc/step-ca
ExecStart=/usr/bin/step-ca config/ca.json --password-file password.txt
ExecReload=/bin/kill --signal HUP 
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start Step-ca service 

systemctl daemon-reload
systemctl enable --now step-ca
#systemctl restart step-ca
#systemctl status step-ca

# Verify
sleep 10
echo ""
curl -k https://$HIP:$CA_PORT/acme/acme/directory
