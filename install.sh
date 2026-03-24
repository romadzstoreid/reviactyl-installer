#!/bin/bash
set -e

######################################################################################
#                                                                                                                      #
#                                 Project 'SapuraHost Theme Installer'                                                #
#                                                                                                                     #
#                                  Copyright 2026, Romadz Store ID                                                #
#                                                                                                                     #
######################################################################################

export SCRIPT_RELEASE="v1.2.0"
LOG_PATH="/var/log/sapurahost-installer.log"
BACKUP_DIR="/root/sapurahost_backups"

BLUE='\033[0;34m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

for cmd in curl zip; do
    if ! [ -x "$(command -v $cmd)" ]; then
        echo -e "${RED}* Error: $cmd diperlukan untuk menjalankan skrip ini.${NC}"
        exit 1
    fi
done

info() { echo -e "${CYAN}──>${NC} $1"; }
success() { echo -e "${GREEN}──>${NC} $1"; }
error() { echo -e "${RED}──> ERROR:${NC} $1"; }

header() {
    clear
    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${LIGHT_BLUE}SAPURAHOST${NC} - THEME AUTO INSTALLER                            ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  Release: ${SCRIPT_RELEASE}                                              ${BLUE}│${NC}"
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

backup_system() {
    info "Memulai pencadangan sistem otomatis..."
    mkdir -p "$BACKUP_DIR"
    local TIMESTAMP=$(date +%F_%H-%M-%S)
    
    cd /var/www/pterodactyl || exit
    
    cp .env "$BACKUP_DIR/.env_$TIMESTAMP"
    
    php artisan db:backup >>$LOG_PATH 2>&1 || {
        info "Menggunakan mysqldump untuk pencadangan database..."
        export $(grep -v '^#' .env | xargs)
        mysqldump -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" > "$BACKUP_DIR/db_$TIMESTAMP.sql" 2>>$LOG_PATH
    }
    
    success "Backup berhasil disimpan di: $BACKUP_DIR"
}

execute_action() {
    local action=$1
    echo -e "\n\n* sapurahost-installer log $(date) \n\n" >>$LOG_PATH
    
    backup_system

    case $action in
        "reviactyl")
            info "Memasang Tema Reviactyl..."
            cd /var/www/pterodactyl || exit
            curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
            finalize
            ;;

        "nook")
            info "Memasang Tema Nook (Nookure)..."
            cd /var/www/pterodactyl || exit
            php artisan down >>$LOG_PATH 2>&1
            curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv >>$LOG_PATH 2>&1
            finalize
            php artisan up >>$LOG_PATH 2>&1
            ;;
            
        "uninstall")
            info "Mengembalikan ke Tema Default (Pterodactyl)..."
            cd /var/www/pterodactyl || exit
            
            cp .env /root/ptero_env_temp
            
            info "Mengunduh source code Pterodactyl..."
            curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
            
            # Kembalikan .env
            mv /root/ptero_env_temp .env
            
            finalize
            ;;
    esac
}

finalize() {
    info "Sinkronisasi dependensi dan migrasi..."
    chmod -R 755 storage/* bootstrap/cache/ >>$LOG_PATH 2>&1
    
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
    
    php artisan view:clear >>$LOG_PATH 2>&1
    php artisan config:clear >>$LOG_PATH 2>&1
    php artisan migrate --seed --force >>$LOG_PATH 2>&1
    
    info "Mengatur perizinan file..."
    chown -R www-data:www-data /var/www/pterodactyl/* >>$LOG_PATH 2>&1
    
    info "Memuat ulang layanan..."
    php artisan queue:restart >>$LOG_PATH 2>&1
    systemctl restart pteroq.service >>$LOG_PATH 2>&1
    systemctl restart nginx >>$LOG_PATH 2>&1
    
    success "Proses selesai dengan sukses!"
}

header
while true; do
    echo -e "${LIGHT_BLUE}MENU UTAMA:${NC}"
    echo -e " [1] Install Tema Reviactyl"
    echo -e " [2] Install Tema Nook (Nookure)"
    echo -e " [3] Uninstall Tema (Kembali ke Default)"
    echo -e " [4] Keluar"
    echo ""
    echo -n -e "${CYAN}Pilih opsi (1-4): ${NC}"
    read -r choice

    case $choice in
        1) execute_action "reviactyl"; break ;;
        2) execute_action "nook"; break ;;
        3) execute_action "uninstall"; break ;;
        4) info "Keluar..."; exit 0 ;;
        *) error "Opsi tidak tersedia." ;;
    esac
done
