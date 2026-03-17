#!/bin/bash

# ==========================================
# Pewarnaan UI Terminal (Aesthetic & Clean)
# ==========================================
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${BLUE}        SAPURAHOST PANEL - AUTO INSTALLER           ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN} Tema: Reviactyl | Menyiapkan Instalasi...          ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

# Pengecekan Akses Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[X] Error: Script ini harus dijalankan sebagai root (gunakan sudo).${NC}"
  exit 1
fi

# Memastikan direktori Pterodactyl ada
if [ ! -d "/var/www/pterodactyl" ]; then
  echo -e "${RED}[X] Error: Direktori /var/www/pterodactyl tidak ditemukan!${NC}"
  exit 1
fi

# Memulai Proses
cd /var/www/pterodactyl || exit

echo -e "${CYAN}[1/9]${NC} Mengamankan file konfigurasi database (.env)..."
cp .env /root/.env_backup

echo -e "${CYAN}[2/9]${NC} Menghapus file panel lama..."
rm -rf *

echo -e "${CYAN}[3/9]${NC} Mengembalikan file konfigurasi database (.env)..."
mv /root/.env_backup .env

echo -e "${CYAN}[4/9]${NC} Mengunduh tema Reviactyl terbaru..."
curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz

echo -e "${CYAN}[5/9]${NC} Mengekstrak file tema..."
tar -xzvf panel.tar.gz
rm panel.tar.gz # Membersihkan file zip agar server tetap bersih

echo -e "${CYAN}[6/9]${NC} Mengatur perizinan folder (chmod)..."
chmod -R 755 storage/* bootstrap/cache/

echo -e "${CYAN}[7/9]${NC} Menginstal dependensi Composer (Tanpa Dev)..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

echo -e "${CYAN}[8/9]${NC} Membangun ulang database (Migrate & Seed)..."
php artisan migrate --seed --force

echo -e "${CYAN}[9/9]${NC} Mengatur Ownership (www-data) & Merestart Service..."
chown -R www-data:www-data /var/www/pterodactyl/*
systemctl restart pteroq.service
systemctl restart nginx

echo ""
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN} [✓] Instalasi Tema Reviactyl Berhasil!             ${NC}"
echo -e "${CYAN}====================================================${NC}"
