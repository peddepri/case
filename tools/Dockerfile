# Toolbox image: terraform + awscli + kubectl + helm
FROM hashicorp/terraform:1.6.6

ARG KUBECTL_VERSION=v1.30.4
ARG HELM_VERSION=v3.14.4

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip bash python3 python3-pip git jq \
 && rm -rf /var/lib/apt/lists/*

# AWS CLI v2 via pip (lightweight alternative)
RUN pip3 install --no-cache-dir --upgrade awscli

# kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl \
    https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && kubectl version --client=true

# helm
RUN curl -fsSL -o /tmp/helm.tgz https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
 && tar -C /tmp -zxvf /tmp/helm.tgz \
 && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
 && chmod +x /usr/local/bin/helm \
 && rm -rf /tmp/* \
 && helm version --client

WORKDIR /workspace
ENTRYPOINT ["bash","-lc"]
CMD ["bash"]
