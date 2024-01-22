#bin/bash

curl -fsSL https://get.docker.com | bash

sudo systemctl start docker

sudo systemctl enable docker

sudo yum install -y epel-release 

sudo yum install -y stress