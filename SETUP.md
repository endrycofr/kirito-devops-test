# Panduan Setup RKE2 & CI/CD Golang

Dokumen ini menjelaskan cara setup dan troubleshooting untuk project Kubernetes RKE2 dengan Golang application.

---

## 📋 Prerequisites

### Hardware Requirements
- **Master Node**: 2 CPU cores, 4GB RAM, 20GB storage
- **Worker Nodes**: 2 CPU cores, 4GB RAM, 20GB storage (per node)
- **Network**: Konektivitas antar nodes terjamin

### Software Requirements
- Linux OS (Ubuntu 20.04+ recommended)
- SSH access ke semua nodes
- Internet connection untuk download images

---

## 🚀 Installation & Setup

### 1. Install RKE2 Cluster

#### Master Node Setup
```bash
# Download dan install RKE2
curl https://get.rke2.io | sh
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# Copy kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Verify master node
kubectl get nodes
kubectl get pods --all-namespaces
```

#### Worker Node Setup
```bash
# Dapatkan token dari master node
TOKEN=$(sudo cat /var/lib/rancher/rke2/server/token)
MASTER_IP=<master-node-ip>

# Install RKE2 worker
curl https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh
sudo systemctl enable rke2-agent.service

# Start agent dengan master node config
sudo systemctl set-environment RKE2_TOKEN=$TOKEN
sudo systemctl set-environment RKE2_URL=https://$MASTER_IP:6443
sudo systemctl start rke2-agent.service

# Verify worker node (dari master)
kubectl get nodes
```

### 2. Install MetalLB (Load Balancing)

```bash
# Create metallb namespace
kubectl create namespace metallb-system

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/manifests/metallb.yaml

# Configure IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Adjust sesuai network Anda
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF

# Verify MetalLB
kubectl get pods -n metallb-system
```

### 3. Install Traefik Ingress Controller

```bash
# Add Traefik Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create ingress namespace
kubectl create namespace ingress

# Install Traefik
helm install traefik traefik/traefik \
  -n ingress \
  --set service.type=LoadBalancer \
  --set service.annotations."metallb\.io/address-pool"=default

# Verify Traefik
kubectl get pods -n ingress
kubectl get svc -n ingress
```

### 4. Install ArgoCD (Optional - untuk GitOps)

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Verify ArgoCD
kubectl get pods -n argocd
```

### 5. Setup Docker Registry (Private)

```bash
# Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

# Verify secret
kubectl get secret regcred
```

---

## 📦 Deploy Golang Application

### 1. Build Docker Image

```bash
# Clone repository
git clone <your-repo-url>
cd kube-golang-app

# Build image
docker build -t myapp:latest .
docker tag myapp:latest <registry-url>/myapp:latest

# Push ke registry
docker push <registry-url>/myapp:latest
```

### 2. Prepare Helm Values

Edit `rke2/values.yaml`:
```yaml
replicaCount: 3

image:
  repository: <registry-url>/myapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
```

### 3. Deploy dengan Helm

```bash
# Install aplikasi
helm install myapp ./rke2 -f rke2/values.yaml

# Verify deployment
kubectl get deployments
kubectl get pods
kubectl get svc

# Check ingress
kubectl get ingress
```

### 4. Verify Aplikasi Berjalan

```bash
# Port forward untuk test
kubectl port-forward svc/myapp 8080:80

# Test via curl
curl http://localhost:8080

# Check logs
kubectl logs -f deployment/myapp
```

---

## 🔧 GitLab CI/CD Configuration

### 1. Create `.gitlab-ci.yml`

```yaml
stages:
  - build
  - push
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  REGISTRY_URL: "registry.example.com"
  IMAGE_NAME: "myapp"
  KUBECONFIG: "/builds/kubeconfig"

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker tag $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_SHA $REGISTRY_URL/$IMAGE_NAME:latest
  only:
    - main

push:
  stage: push
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD $REGISTRY_URL
    - docker push $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_SHA
    - docker push $REGISTRY_URL/$IMAGE_NAME:latest
  only:
    - main

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/myapp myapp=$REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/myapp
  environment:
    name: production
  only:
    - main
```

### 2. Setup GitLab Runner

```bash
# Install GitLab Runner
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Register runner
sudo gitlab-runner register \
  --url https://gitlab.example.com/ \
  --registration-token <your-token> \
  --executor kubernetes \
  --kubernetes-host https://<kubernetes-api>:6443 \
  --kubernetes-cert-file /path/to/cert.crt
```

### 3. Configure CI/CD Variables

Di GitLab project settings → CI/CD → Variables, tambahkan:
- `REGISTRY_URL` - URL Docker Registry
- `REGISTRY_USER` - Username registry
- `REGISTRY_PASSWORD` - Password registry
- `KUBECONFIG` - Encoded kubeconfig file (base64)

---

## 🐛 Troubleshooting

### Pod tidak jalan (ImagePullBackOff)

```bash
# Check pod events
kubectl describe pod <pod-name>

# Verify docker credentials
kubectl get secret regcred --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode

# Recreate secret jika perlu
kubectl delete secret regcred
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass>
```

### Service tidak mendapat External IP

```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl describe ipaddresspool -n metallb-system

# Check service
kubectl describe svc <service-name>

# Verify network pool availability
kubectl logs -n metallb-system deployment/controller
```

### Node Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
sudo journalctl -u rke2-agent -f

# Restart RKE2 service
sudo systemctl restart rke2-agent
```

### Pod Communication Issues

```bash
# Test connectivity antar pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Dari container, test DNS
nslookup kubernetes.default

# Test service access
wget -O- http://<service-name>.<namespace>.svc.cluster.local
```

---

## 📊 Monitoring & Logging

### Check Cluster Health

```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes -o wide

# Resource usage
kubectl top nodes
kubectl top pods

# Event logs
kubectl get events --sort-by='.lastTimestamp'
```

### Access Application Logs

```bash
# Real-time logs
kubectl logs -f deployment/myapp

# Specific pod logs
kubectl logs <pod-name>

# Previous pod logs (jika crash)
kubectl logs <pod-name> --previous
```

---

## 🔐 Security Best Practices

1. **RBAC Configuration** - Terapkan Role Based Access Control
2. **Network Policies** - Batasi traffic antar pod
3. **Secret Management** - Gunakan Secret untuk credentials
4. **Resource Limits** - Set CPU/Memory limits untuk pod
5. **Registry Authentication** - Gunakan private registry dengan credentials

---

## 📖 References

- [RKE2 Documentation](https://docs.rke2.io/)
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Traefik Documentation](https://doc.traefik.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)

---

**Last Updated:** February 2026