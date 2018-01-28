#!/bin/sh

echo "Generating CA certificate..."
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

if [ ! -f ca-key.pem ]||[ ! -f ca.pem ]; then
    echo "Error creating CA certificates"
    exit -1
fi

echo "Generating admin certificate..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

if [ ! -f admin-key.pem ]||[ ! -f admin.pem ]; then
    echo "Error creating admin certificate"
    exit -1
fi

for instance in worker-0 worker-1 worker-2; do
    EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
    --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

    INTERNAL_IP=$(gcloud compute instances describe ${instance} \
    --format 'value(networkInterfaces[0].networkIP)')

    echo "Generating ${instance} certificate..."
    cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
    -profile=kubernetes \
    ${instance}-csr.json | cfssljson -bare ${instance}

    if [ ! -f ${instance}-key.pem ]||[ ! -f ${instance}.pem ]; then
        echo "Error creating ${instance} certificates"
        exit -1
    fi
done

echo "Generating kube-proxy certificate..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

if [ ! -f kube-proxy-key.pem ]||[ ! -f kube-proxy.pem ]; then
    echo "Error creating kube-proxy certificates"
    exit -1
fi

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-easy-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

echo "Generating kubernetes certificate..."
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

if [ ! -f kubernetes-key.pem ]||[ ! -f kubernetes.pem ]; then
    echo "Error creating kubernetes certificates"
    exit -1
fi