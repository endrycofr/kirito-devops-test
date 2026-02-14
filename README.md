# Kube & CI/CD App Golang

Project ini adalah contoh implementasi **DevOps end-to-end** dengan **Golang**, menggunakan **RKE2 Kubernetes** sebagai cluster dan **GitLab CI/CD** untuk otomatisasi build, push, dan deploy aplikasi.

---

## 🔹 Arsitektur Cluster RKE2

Berikut adalah arsitektur cluster Kubernetes RKE2 dengan 1 Master Node dan 3 Slave Nodes:

![RKE2 Cluster Architecture](https://github.com/endrycofr/kirito-devops-test/blob/master/img/rke2-cluster-architecture.png)

**Komponen Master Node:**
- **API Server** - Mengelola semua request dan state cluster
- **Control Manager** - Mengontrol node, pod, dan resource lainnya
- **Scheduler** - Menentukan placement pod ke worker nodes
- **etcd** - Database distributed untuk menyimpan state cluster

**Komponen Setiap Slave Node:**
- **kubelet** - Agent yang menjalankan container
- **kube-proxy** - Network proxy untuk komunikasi pod
- **Container Runtime** - Docker yang menjalankan Pod 1 dan Pod 2

---

## 🔹 Arsitektur & Flow CI/CD

Berikut flow lengkap GitLab CI/CD hingga deployment ke Kubernetes:

![GitLab CI/CD Flow](https://github.com/endrycofr/kirito-devops-test/blob/master/img/gitlab-cicd-flow.png)

**Pipeline Flow:**

1. **Developer Commit & Push Code** ke repository GitLab
2. **GitLab CI Pipeline** dijalankan:
   - Build Docker image dari Dockerfile
   - Tag dan push image ke Docker Registry
3. **Update Manifest Values** - Update `values.yaml` di Manifest Repository dengan image tag terbaru
4. **ArgoCD Sync** - ArgoCD mendeteksi perubahan manifest
5. **Deploy ke Kubernetes** - Manifest di-apply ke cluster RKE2 via Helm Chart

---

## 🔹 Arsitektur Load Balancing & Ingress

Berikut adalah arsitektur network dan load balancing dengan MetalLB dan Traefik Ingress:

![Load Balancing Architecture](https://github.com/endrycofr/kirito-devops-test/blob/master/img/load-balancing-architecture.png)

**Komponen Baremetal (On-Premises):**
- **LB SVC 1** - Service Load Balancer yang mendistribusikan traffic ke 3 worker nodes

**Komponen Kubernetes Cluster:**
- **MetalLB VIP (External IP)** - Virtual IP dari MetalLB untuk mengexpose service ke external network
- **Traefik Ingress Controller** - Mengelola routing HTTP traffic berdasarkan hostname/path
- **LB SVC Worker 1, 2, 3** - Worker nodes yang menjalankan pod aplikasi
- **HTTP Routes 1, 2, 3** - Routing rules untuk setiap service

---

## 🔹 Tools yang Digunakan

| Kategori           | Tools                     | Keterangan                                     |
| ------------------ | ------------------------- | ---------------------------------------------- |
| **Containerization** | Docker                   | Build image aplikasi Golang                    |
| **Kubernetes Cluster** | RKE2                    | Cluster Kubernetes untuk deploy aplikasi       |
| **CI/CD Pipeline**  | GitLab CI/CD              | Pipeline otomatis build, push, deploy          |
| **Container Registry** | Docker Registry          | Menyimpan image yang sudah dibuild             |
| **Package Manager** | Helm                      | Deploy dan manage aplikasi di Kubernetes       |
| **GitOps**          | ArgoCD                    | Sync manifest ke cluster secara otomatis       |
| **Load Balancing**  | MetalLB                   | Assign external IP di environment on-premises  |
| **Ingress Controller** | Traefik                 | HTTP routing dan load balancing                |
| **Language**        | Go Modules                | Manage dependencies Golang                     |
| **Monitoring**      | kubectl                   | Mengecek status pod, service, deployment       |

---

## 🔹 Struktur Repository

```
├── rke2/                      # Kubernetes manifests untuk RKE2
│   ├── templates/
│   │   ├── service/
│   │   ├── ingress/
│   │   └── deployment/
│   ├── Chart.yaml
│   └── values.yaml
├── kubeconfig/                # File kubeconfig akses cluster
├── Dockerfile                 # Build Golang image
├── .gitlab-ci.yml             # Pipeline CI/CD GitLab
├── main.go                    # Source code Golang
├── go.mod / go.sum            # Go dependencies
├── img/                      # foto & diagram arsitektur
│   ├── rke2-cluster-architecture.png
│   ├── gitlab-cicd-flow.png
│   └── load-balancing-architecture.png
└── README.md                  # Dokumentasi ini
```

---

## 🔹 GitLab CI/CD Pipeline

Pipeline otomatis mengikuti tahapan berikut:

### **1. Build Stage**
- Build Docker image dari Dockerfile yang berisi aplikasi Golang
- Menjalankan `docker build` dengan context dari repository

### **2. Push Stage**
- Push image ke Docker Registry dengan tag latest dan commit SHA
- Memastikan image tersedia untuk digunakan saat deployment

### **3. Deploy Stage**
- Update nilai image di Manifest Repository (values.yaml)
- ArgoCD mendeteksi perubahan dan melakukan sync otomatis
- Deploy ke cluster RKE2 menggunakan Helm Chart

**Persyaratan:**
- GitLab Runner harus memiliki akses ke kubeconfig RKE2
- Docker Registry credentials dikonfigurasi di GitLab CI/CD variables
- Manifest Repository dan cluster harus accessible dari runner

---

## 🔹 Quick Start

### Prerequisites
```bash
# Install RKE2
curl https://get.rke2.io | sh

# Install kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Deploy Aplikasi
```bash
# Clone repository
git clone <your-repo-url>
cd kube-golang-app

# Configure kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Deploy menggunakan Helm
helm install my-app ./rke2 -f rke2/values.yaml

# Verify deployment
kubectl get pods -n default
kubectl get svc -n default
```

---

## 🔹 Project Sebelumnya

Oke, kalau begitu bagian **referensi proyek sebelumnya** bisa kita update untuk menjelaskan konteks RKE2, sekaligus menampilkan link ke proyek lama yang menggunakan K3s dan VM provisioning. Misalnya bisa ditulis di README bagian *Acknowledgments* atau *References*:

---

* [k3s DevOps Project](https://github.com/endrycofr/Ansible_k3s.git) – Versi sebelumnya menggunakan **K3s** cluster dengan arsitektur sederhana berbasis Ansible. Cocok sebagai referensi atau migrasi ke **RKE2**.
* [VM Provisioning Vagrant](https://github.com/endrycofr/Vagrant_VM.git) – Skrip provisioning **VirtualBox VMs** untuk environment development dan testing.


---

## 📝 Notes

- Pastikan semua node terhubung dengan baik sebelum deployment
- Monitor logs dengan `kubectl logs -f <pod-name>`
- Gunakan `kubectl describe pod <pod-name>` untuk debugging
- ArgoCD dapat diakses melalui Traefik Ingress setelah dikonfigurasi

---

---
