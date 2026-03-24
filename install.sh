#!/bin/bash
set -e

# Konfigurasi Dasar
export SCRIPT_RELEASE="v1.2.0"
LOG_PATH="/var/log/sapurahost-installer.log"
INSTALLER_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer/master/installer.sh"

# Warna (Soft Blue Palette)
SOFT_BLUE='\e[38;5;111m'
WHITE='\e[97m'
GREEN='\e[38;5;114m'
RED='\e[38;5;167m'
YELLOW='\e[38;5;222m'
NC='\e[0m'

# Check dependencies
if ! [ -x "$(command -v curl)" ]; then
    echo -e "${RED}* Error: curl diperlukan untuk menjalankan script ini.${NC}"
    exit 1
fi

output() {
    echo -e "${SOFT_BLUE}✦${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}✦ ERROR:${NC} ${WHITE}$1${NC}"
}

welcome() {
    local width=60
    local title="SAPURAHOST - ALL IN ONE INSTALLER"
    local release="Script Release: ${SCRIPT_RELEASE}"

    local pad_title=$(( (width - ${#title}) / 2 ))
    local pad_rel=$(( (width - ${#release}) / 2 ))

    clear
    echo -e "${SOFT_BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${SOFT_BLUE}║$(printf '%*s' $width "")║${NC}"   
    echo -ne "${SOFT_BLUE}║${WHITE}"
    printf "%*s%s%*s" $pad_title "" "$title" $((width - pad_title - ${#title})) ""
    echo -e "${SOFT_BLUE}║${NC}"    
    echo -ne "${SOFT_BLUE}║${SOFT_BLUE}"
    printf "%*s%s%*s" $pad_rel "" "$release" $((width - pad_rel - ${#release})) ""
    echo -e "${SOFT_BLUE}║${NC}"    
    echo -e "${SOFT_BLUE}║$(printf '%*s' $width "")║${NC}"
    echo -e "${SOFT_BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

execute_action() {
    local action=$1
    echo -e "\n\n* SapuraHost-Installer $(date) - Action: $action \n\n" >>$LOG_PATH

    case $action in
        "install_panel")
            output "Menjalankan Pterodactyl Panel Installer..."
            bash <(curl -sSL "$INSTALLER_URL") <<< "0"
            ;;
            
        "install_wings")
            output "Menjalankan Pterodactyl Wings Installer..."
            bash <(curl -sSL "$INSTALLER_URL") <<< "1"
            ;;

        "install_both")
            output "Menjalankan Instalasi Panel & Wings..."
            bash <(curl -sSL "$INSTALLER_URL") <<< "2"
            ;;

        "install_reviactyl")
            output "Memasang Tema Reviactyl..."
            cd /var/www/pterodactyl || { error "Direktori panel tidak ditemukan!"; return; }
            cp .env /root/.env_backup
            rm -rf * && mv /root/.env_backup .env
            curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz
            tar -xzvf panel.tar.gz && rm panel.tar.gz
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
            php artisan migrate --seed --force
            finalize
            ;;
            
        "install_nook")
            output "Memasang Tema Nookure..."
            cd /var/www/pterodactyl || { error "Direktori panel tidak ditemukan!"; return; }
            php artisan down
            curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv
            chmod -R 755 storage/* bootstrap/cache
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
            php artisan view:clear && php artisan config:clear
            php artisan migrate --seed --force
            php artisan queue:restart && php artisan up
            finalize
            ;;
            
        "del_services")
            output "Menjalankan Uninstaller (Panel/Wings)..."
            # Menggunakan opsi uninstall dari script komunitas
            bash <(curl -sSL "$INSTALLER_URL") <<< "uninstall"
            ;;

        "uninstall_theme")
            output "Mengembalikan ke Tema Default..."
            cd /var/www/pterodactyl || { error "Direktori panel tidak ditemukan!"; return; }
            cp .env /root/.env_backup
            rm -rf * && mv /root/.env_backup .env
            curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
            tar -xzvf panel.tar.gz && rm panel.tar.gz
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
            php artisan view:clear && php artisan config:clear
            finalize
            ;;
    esac
}

finalize() {
    output "Sinkronisasi perizinan & restart service..."
    chown -R www-data:www-data /var/www/pterodactyl/* >>$LOG_PATH 2>&1
    systemctl restart pteroq nginx >>$LOG_PATH 2>&1
    echo -e "\n${GREEN}✦ Selesai! Panel telah diperbarui.${NC}\n"
}

# Main Menu Logic
while true; do
    welcome
    options=(
        "Install Pterodactyl Panel"
        "Install Wings"
        "Install Panel & Wings (Satu Server)"
        "Install Tema Reviactyl"
        "Install Tema Nookure"
        "Hapus (Uninstall) Panel/Wings"
        "Hapus Tema (Back to Default)"
        "Keluar"
    )
    actions=(
        "install_panel"
        "install_wings"
        "install_both"
        "install_reviactyl"
        "install_nook"
        "del_services"
        "uninstall_theme"
        "exit"
    )

    output "Pilih opsi di bawah ini:"
    for i in "${!options[@]}"; do
        echo -e "  ${SOFT_BLUE}[$i]${NC} ${WHITE}${options[$i]}${NC}"
    done
    echo ""

    echo -ne "${YELLOW}✦ Masukkan nomor pilihan (0-$((${#actions[@]} - 1))): ${NC}"
    read -r choice

    if [[ ! "$choice" =~ ^[0-7]$ ]]; then
        error "Pilihan tidak valid."
        sleep 2
        continue
    fi

    if [ "$choice" == "7" ]; then
        output "Terima kasih telah menggunakan SapuraHost Installer!"
        exit 0
    fi

    execute_action "${actions[$choice]}"
    
    echo -ne "${YELLOW}✦ Tekan ENTER untuk kembali ke menu...${NC}"
    read -r
done
