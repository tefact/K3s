#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# install-k3s.sh
# Script instalasi K3s single-node untuk workshop Debug Life Indonesia
# Tested on: Ubuntu 22.04 (AWS EC2)
#
# Arsitektur deploy:
#   GitHub Actions → SSH ke EC2 → kubectl dijalankan LOKAL di EC2
#   K3s tidak perlu expose port 6443 ke internet.
#   Tidak perlu --tls-san.
# ─────────────────────────────────────────────────────────────────

set -e  # stop kalau ada error

echo ""
echo "======================================================"
echo "  Debug Life Indonesia — K3s Workshop Installer"
echo "======================================================"
echo ""

# ── Step 1: Update system ──────────────────────────────────────
echo "[1/4] Updating system packages..."
sudo apt-get update -q

# ── Step 2: Install K3s (plain, tanpa --tls-san) ───────────────
echo ""
echo "[2/4] Installing K3s..."
echo "      Ini mungkin butuh 1-2 menit. Jangan close terminal!"
echo ""

# K3s listen di 127.0.0.1:6443 (lokal).
# GitHub Actions akan deploy via SSH — kubectl jalan di EC2 langsung.
# Tidak perlu expose port 6443 ke internet.
curl -sfL https://get.k3s.io | sh -

echo ""
echo "[3/4] Menunggu K3s service ready..."
sleep 15

# ── Step 3: Setup kubeconfig untuk user biasa ─────────────────
echo "[4/4] Configuring kubectl access..."

mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config
chmod 600 $HOME/.kube/config

export KUBECONFIG=$HOME/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> $HOME/.bashrc

# ── Verifikasi node Ready ─────────────────────────────────────
echo "Waiting for node to be Ready..."
for i in {1..12}; do
    STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}')
    if [ "$STATUS" = "Ready" ]; then
        break
    fi
    echo "  ... ($i/12) Node status: ${STATUS:-pending}"
    sleep 5
done

echo ""
echo "======================================================"
echo "  ✓ K3s installed successfully!"
echo "======================================================"
echo ""
kubectl get nodes
echo ""

# ── Instruksi setup GitHub Secrets (SSH approach) ─────────────
EC2_PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "<your-ec2-ip>")

echo ""
echo "======================================================"
echo "  NEXT: Setup GitHub Secrets (3 secrets dibutuhkan)"
echo "======================================================"
echo ""
echo "Buka: GitHub repo → Settings → Secrets → Actions"
echo ""
echo "1. EC2_HOST"
echo "   Value: $EC2_PUBLIC_IP"
echo ""
echo "2. EC2_USER"
echo "   Value: ubuntu"
echo "   (atau sesuaikan dengan user SSH EC2 kamu)"
echo ""
echo "3. EC2_SSH_KEY"
echo "   Value: isi file .pem kamu (SELURUH isi, mulai dari"
echo "   '-----BEGIN RSA PRIVATE KEY-----' sampai akhir)"
echo "   Cara lihat: cat /path/to/your-key.pem"
echo ""
echo "Deploy berjalan otomatis saat push ke branch main."
echo "kubectl dijalankan LOKAL di EC2 ini via SSH."
echo "Port 6443 TIDAK perlu dibuka ke internet."
echo ""
echo "======================================================"