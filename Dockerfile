FROM docker:dind
LABEL maintainer strokovnjaka

# version e.g. 1.0.11
ARG TERRAFORM_VERSION=1.0.11

RUN apk add --update --no-cache wget unzip curl bash 

## Terraform
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -P /tmp
RUN unzip /tmp/terraform*.zip -d /usr/bin/ && rm -f /tmp/terraform*.zip

## Azure cli
RUN apk add --no-cache --virtual=build gcc libffi-dev musl-dev openssl-dev python3-dev py3-pip py3-pynacl rpm
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc
COPY azure-cli.repo /etc/yum.repos.d/azure-cli.repo
RUN pip install --upgrade pip
RUN pip install azure-cli

## Copy tf files, auto az login
COPY deploy/ /home/deploy/
COPY tftrain/ /home/tftrain/
COPY mailto/mailto.py /home/tftrain/
COPY generatedata/ /home/generatedata/
COPY mailto/mailto.py /home/generatedata/
COPY .bashrc /root/
