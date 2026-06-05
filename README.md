# Workshop K8s 101 — Debug Life Indonesia
> *Deploy Pertamamu ke Kubernetes. Dari nol sampai pipeline jalan — di EC2-mu sendiri.*

---

## Arsitektur Deploy

```
git push → GitHub Actions
               │
               ├─ Job 1: Build & Push Docker image ke ghcr.io
               │
               └─ Job 2: SSH ke EC2
                           │
                           └─ kubectl apply (jalan LOKAL di EC2)
                                       │
                                       └─ K3s cluster (127.0.0.1:6443)
```

> **Port 6443 tidak perlu dibuka ke internet.** GitHub Actions deploy via SSH,
> bukan konek langsung ke API server. Tidak ada TLS SAN issue.

---

## Struktur Repo

```
workshop-k3s/
├── app/
│   ├── main.py           ← Flask app sederhana
│   └── requirements.txt  ← Python dependencies
├── k8s/
│   ├── deployment.yaml   ← Definisi pod & replicas
│   └── service.yaml      ← Expose app ke luar (LoadBalancer)
├── .github/
│   └── workflows/
│       └── deploy.yml    ← CI/CD pipeline (SSH deploy)
├── Dockerfile            ← Recipe untuk build image
├── install-k3s.sh        ← Script install K3s
└── README.md             ← Kamu di sini
```

---

## Hands-On: 7 Steps

### STEP 1 — SSH ke EC2

```bash
# Pastikan permission key sudah benar
chmod 400 workshop.pem

# SSH ke EC2 (username default EC2 Ubuntu = "ubuntu")
ssh -i workshop.pem ubuntu@<EC2-PUBLIC-IP>
```

> **Credential** ada di channel `#workshop` di Discord.

**Troubleshooting SSH:**
| Error | Penyebab | Fix |
|-------|----------|-----|
| `Permission denied (publickey)` | chmod belum 400 | `chmod 400 workshop.pem` |
| `Warning: Unprotected private key` | Permission file terlalu lebar | `chmod 400 workshop.pem` |
| `Connection timed out` | Security Group belum buka port 22 | Cek inbound rules EC2 |

---

### STEP 2 — Clone Repo Workshop

```bash
git clone https://github.com/Deri-Nugroho/K3s.git
cd K3s
ls
```

**Output yang harus muncul:**
```
app/  k8s/  .github/  Dockerfile  install-k3s.sh  README.md
```

---

### STEP 3 — Install K3s

```bash
bash install-k3s.sh
```

Script ini otomatis:
1. Update system packages
2. Install K3s (plain, tanpa `--tls-san` — tidak perlu!)
3. Setup kubectl tanpa sudo
4. Verifikasi node Ready
5. Print panduan setup GitHub Secrets

**Estimasi: 2–3 menit. Jangan close terminal!**

Verifikasi manual setelah install:
```bash
kubectl get nodes
# NAME             STATUS   ROLES                  AGE
# ip-172-31-xx-xx  Ready    control-plane,master   2m
```

---

### STEP 4 — Setup GitHub Secrets (3 Secrets)

GitHub Actions konek ke EC2 via **SSH key** — kubectl jalan **lokal di EC2** pakai `~/.kube/config` milik user ubuntu.

> 🚫 **JANGAN buat secret `KUBECONFIG`.**
> Panduan lain yang minta `sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0` adalah untuk pendekatan *remote kubectl* (konek dari luar ke port 6443).
> Workshop ini pakai SSH — **tidak perlu itu sama sekali**.

**a) Dapatkan nilai untuk setiap secret:**

```bash
# Di terminal EC2 — jalankan untuk dapat public IP
curl -s ifconfig.me
```

**b) Tambahkan 3 secret ke GitHub:**

Buka repo → `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Secret Name | Value |
|-------------|-------|
| `EC2_HOST` | Public IP EC2, contoh: `3.210.198.54` |
| `EC2_USER` | Username SSH, contoh: `ubuntu` |
| `EC2_SSH_KEY` | **Seluruh isi** file `.pem` — dari `-----BEGIN RSA PRIVATE KEY-----` sampai `-----END RSA PRIVATE KEY-----` |

> ⚠️ **`EC2_SSH_KEY` harus seluruh isi file `.pem`, termasuk header & footer.**
> Cara lihat: `cat /path/to/workshop.pem`
> Copy semua — paste ke secret value as-is (multi-line diperbolehkan GitHub).

> ⚠️ **Jangan pernah commit file `.pem` ke repo. Ever.**

**c) Pastikan port 22 terbuka di Security Group EC2:**

```
AWS Console → EC2 → Security Groups → Inbound Rules
Type   : SSH
Port   : 22
Source : 0.0.0.0/0   (atau batasi ke IP spesifik untuk keamanan)
```

**Troubleshooting Step 4:**
| Error | Penyebab | Fix |
|-------|----------|-----|
| `ssh: handshake failed: unable to authenticate` | EC2_SSH_KEY salah / terpotong | Paste ulang isi `.pem` lengkap |
| `dial tcp: connection refused` | EC2_HOST salah | Cek public IP EC2 di console AWS |
| `dial tcp: i/o timeout` | Port 22 tidak terbuka | Buka port 22 di Security Group |

---

### STEP 5 — Trigger Pipeline Pertama

```bash
git add .
git commit -m "trigger: first deploy"
git push origin main
```

**Pantau progress pipeline:**
1. Buka `github.com/<username>/K3s`
2. Klik tab `Actions`
3. Klik workflow run terbaru
4. Lihat log real-time — ada 2 job: **Build Docker Image** → **Deploy to K3s via SSH**
5. Tunggu ✓ hijau (~2–3 menit)

> ⚠️ **Pastikan GitHub Container Registry package di-set Public!**
> `github.com/<username>` → tab Packages → `workshop-k3s` → Package settings → Change visibility → Public
> Tanpa ini K3s tidak bisa pull image dan pod akan `ImagePullBackOff`.

---

### STEP 6 — Verifikasi App Jalan

```bash
kubectl get pods
# NAME                            READY   STATUS    RESTARTS   AGE
# workshop-app-76d48c88df-xxxxx   1/1     Running   0          42s

kubectl get svc
# NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# workshop-app   ClusterIP   10.43.106.147   <none>        80/TCP    42s

kubectl get ingress
# NAME           CLASS     HOSTS   ADDRESS         PORTS   AGE
# workshop-app   traefik   *       3.210.198.54    80      42s
```

**Kalau STATUS = Running dan Ingress ada ADDRESS → kamu berhasil! 🎉**

Buka browser:
```
http://<EC2-PUBLIC-IP>
```
> Port **80** langsung via Traefik — tidak perlu port tambahan.

> 💡 **Kenapa pakai Ingress, bukan LoadBalancer langsung?**
> K3s default install **Traefik** sebagai ingress controller — Traefik sudah bind port 80.
> Kalau Service pakai `LoadBalancer`, Klipper ServiceLB tidak bisa bind port 80 (sudah dipakai Traefik)
> sehingga EXTERNAL-IP stuck `<pending>`.
> Solusinya: pakai `ClusterIP` + `Ingress` — Traefik routing traffic ke app via Ingress rule.
> Traffic flow: `http://<EC2-IP>` → **Traefik (port 80)** → **Service (ClusterIP)** → **Pod (5000)**

> ⚠️ **Pastikan Security Group EC2 membuka port 80 (inbound, TCP)**


---

### BONUS STEP — Self-Healing Demo

```bash
# 1. Catat nama pod yang sedang running
kubectl get pods

# 2. Bunuh pod-nya dengan sengaja
kubectl delete pod workshop-app-xxxxx-yyyyy

# 3. Pantau langsung — jalankan segera setelah delete
kubectl get pods -w
```

Dalam ~5 detik:
```
NAME                            READY   STATUS        AGE
workshop-app-76d48c88df-xxxxx   1/1     Terminating   5m
workshop-app-76d48c88df-yyyyy   0/1     Pending       1s
workshop-app-76d48c88df-yyyyy   1/1     Running       4s
```

**Pod lama mati → pod baru lahir otomatis. Inilah self-healing Kubernetes.**

```
Deployment (replicas: 1)
    ↓ deteksi pod mati
Controller Loop
    ↓ buat pod baru
Pod baru → Running
    ↓
Service tetap hidup (port 80 tidak pernah down)
```

---

## Troubleshooting Umum

```bash
# Cek status pod
kubectl get pods

# Detail error pod (lihat bagian Events di bawah output)
kubectl describe pod <nama-pod>

# Lihat log app
kubectl logs <nama-pod>

# Lihat log K3s live
sudo journalctl -u k3s -f

# Cek status service K3s
sudo systemctl status k3s

# Restart K3s
sudo systemctl restart k3s

# Fix kubeconfig lokal kalau kubectl tiba-tiba tidak bisa connect
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config
```

**Pod `ImagePullBackOff`?**
```bash
# Cek image apa yang dicoba di-pull
kubectl describe pod <nama-pod> | grep -A5 "Events:"
# Solusi: jadikan GitHub Container Registry package = Public
```

**Service dapat EXTERNAL-IP `<pending>` terus?**
```bash
# Cek apakah Klipper LB berjalan
kubectl get pods -n kube-system | grep svclb
# Harus ada pod svclb-workshop-app-xxxxx STATUS Running
```

---

## 8 Command Wajib Fasilitator

```bash
kubectl get nodes            # cek status cluster
kubectl get pods             # cek pod running/tidak
kubectl get svc              # cek service & EXTERNAL-IP
kubectl describe pod <pod>   # detail pod — untuk debug ImagePullBackOff, CrashLoop, dll
kubectl logs <pod>           # lihat log app
kubectl delete pod <pod>     # hapus pod (untuk demo self-healing)
sudo systemctl status k3s    # cek K3s service
sudo journalctl -u k3s -f    # live log K3s
```

---

## Stack Workshop

| Komponen | Tool | Fungsi |
|----------|------|--------|
| CI/CD | GitHub Actions | Trigger pipeline tiap `git push` |
| Deploy method | SSH via `appleboy/ssh-action` | Jalankan kubectl di EC2 secara lokal |
| Container | Docker | Bungkus app jadi image |
| Registry | GitHub Container Registry (ghcr.io) | Simpan Docker image — **harus Public** |
| Orchestrator | K3s | Kubernetes ringan untuk EC2 |
| Load Balancer | Klipper ServiceLB (built-in K3s) | Assign EXTERNAL-IP ke Service type LoadBalancer |

---

## Catatan EC2 vs VPS Biasa

| Aspek | VPS Biasa | AWS EC2 (Workshop ini) |
|-------|-----------|------------------------|
| SSH | `ssh user@ip -p port` | `ssh -i key.pem ubuntu@ip` |
| Install K3s | `curl ... \| sh -` | `curl ... \| sh -` (sama — tak perlu `--tls-san`) |
| Deploy method | SSH ke VPS → kubectl lokal | SSH ke EC2 → kubectl lokal |
| Service type | `LoadBalancer` | `LoadBalancer` (Klipper built-in K3s) |
| Akses app | `http://IP:80` | `http://IP:80` |
| GitHub Secrets | `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` | `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` |

---

*debug life indonesia · inspect · reflect · refactor · 2026*