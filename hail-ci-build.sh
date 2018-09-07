#!/bin/bash

set -ex

gcloud auth activate-service-account \
     hail-ci-0-1@broad-ctsa.iam.gserviceaccount.com \
     --key-file=/secrets/hail-ci-0-1.key

gcloud config set project broad-ctsa

pip install ./

CLUSTER_NAME_0_2=cloudtools-ci-$(LC_CTYPE=C LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
CLUSTER_NAME_0_1=cloudtools-ci-$(LC_CTYPE=C LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)

shutdown_cluster() {
    set +e
    time gcloud dataproc clusters delete ${CLUSTER_NAME_0_2} --async
    time gcloud dataproc clusters delete ${CLUSTER_NAME_0_1} --async
    exit
}
trap shutdown_cluster EXIT

trap "exit 42" INT TERM

# check binary exists
time cluster start --help

# check 0.2 cluster starts and runs hail
time cluster start ${CLUSTER_NAME_0_2} \
     --version devel \
     --spark 2.2.0 \
     --bucket=hail-ci-0-1-dataproc-staging-bucket
time cluster submit ${CLUSTER_NAME_0_2} \
     cluster-sanity-check-0.2.py
time cluster stop --async ${CLUSTER_NAME_0_2}

# check 0.1 cluster starts and runs hail
time cluster start ${CLUSTER_NAME_0_1} \
     --version 0.1 \
     --spark 2.0.2 \
     --bucket=hail-ci-0-1-dataproc-staging-bucket
time cluster submit ${CLUSTER_NAME_0_1} \
     cluster-sanity-check-0.1.py
time cluster stop --async ${CLUSTER_NAME_0_1}
