#!/bin/bash
set -e

######################################################################################
#                                                                                    #
# Project 'SapuraHost Theme Installer'                                               #
#                                                                                    #
# Copyright (C) 2025 - 2026, Romadz, <https://github.com/romadzstoreid>              #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/romadzstoreid/reviactyl-installer                               #
#                                                                                    #
######################################################################################

# Export Variabel Dasar
export SCRIPT_RELEASE="v1.0.0"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/romadzstoreid/reviactyl-installer"
LOG_PATH="/var/log/sapurahost-installer.log"

# Warna untuk UI
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for curl
if ! [ -x "$(command -v curl)" ]; then
    echo "* curl is required in order for this script to work."
    exit 1
fi

# Fungsi Header
output() {
    echo -e "${CYAN}*${NC} $1"
}

error() {
    echo -e "${RED}* ERROR: $1${NC}"
}

welcome() {
    clear
    echo -e "${BLUE}######################################################################${NC}"
    echo -e "${BLUE}#                                                                    #${NC}"
    echo -e "${BLUE}#                SAPURAHOST - THEME AUTO INSTALLER                   #${NC}"
    echo -e "${BLUE}#                Script Release: ${SCRIPT_RELEASE}                               #${NC}"
    echo -e "${BLUE}#                                                                    #${NC}"
    echo -e "${BLUE}######################################################################${NC}"
    echo ""
}

# Fungsi Eksekusi Utama
execute_action() {
    local action=$1
    echo -e "\n\n* sapurahost-installer $(date) \n\n" >>$LOG_PATH

    case $action in
        "install")
            output "Memulai Instalasi Tema Reviactyl..."
            cd /var/www/pterodactyl || exit
            output "Mengamankan konfigurasi .env..."
            cp .env /root/.env_backup >>$LOG_PATH 2>&1
            
            output "Membersihkan direktori lama..."
            rm -rf * >>$LOG_PATH 2>&1
            mv /root/.env_backup .env
            
            output "Mengunduh file tema..."
            curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
            
            output "Menyelesaikan proses (ini mungkin memakan waktu)..."
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            php artisan migrate --seed --force >>$LOG_PATH 2>&1
            finalize
            ;;
            
        "uninstall")
            output "Mengembalikan Panel ke Tema Default..."
            cd /var/www/pterodactyl || exit
            cp .env /root/.env_backup >>$LOG_PATH 2>&1
            
            output "Menghapus tema saat ini..."
            rm -rf * >>$LOG_PATH 2>&1
            mv /root/.env_backup .env
            
            output "Mengunduh Panel Pterodactyl resmi..."
            curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
            
            output "Membangun ulang struktur default..."
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            php artisan view:clear >>$LOG_PATH 2>&1
            php artisan config:clear >>$LOG_PATH 2>&1
            finalize
            ;;
    esac
}

finalize() {
    output "Mengatur kepemilikan file..."
    chown -R www-data:www-data /var/www/pterodactyl/* >>$LOG_PATH 2>&1
    output "Merestart layanan (Nginx & PteroQ)..."
    systemctl restart pteroq.service
    systemctl restart nginx
    echo -e "\n${GREEN}* Proses selesai dengan sukses!${NC}"
    echo -e "${CYAN}* Log instalasi dapat dilihat di: ${LOG_PATH}${NC}"
}

# Logic Menu Seperti pterodactyl-installer.se
welcome
done=false
while [ "$done" == false ]; do
    options=(
        "Install Tema Reviactyl"
        "Uninstall Tema Reviactyl (Kembali ke Default)"
        "Keluar dari Installer"
    )
    actions=(
        "install"
        "uninstall"
        "exit"
    )

    output "Apa yang ingin Anda lakukan?"
    for i in "${!options[@]}"; do
        output "[$i] ${options[$i]}"
    done

    echo -n "* Masukkan pilihan (0-$((${#actions[@]} - 1))): "
    read -r action

    if [ -z "$action" ] || [[ ! "0 1 2" =~ $action ]]; then
        error "Pilihan tidak valid, coba lagi."
        continue
    fi

    if [ "$action" == "2" ]; then
        output "Keluar..."
        done=true
        exit 0
    fi

    done=true
    execute_action "${actions[$action]}"
done
