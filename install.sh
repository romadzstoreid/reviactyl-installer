#!/bin/bash
set -e

export SCRIPT_RELEASE="v1.1.0"
LOG_PATH="/var/log/sapurahost-installer.log"

SOFT_BLUE='\e[38;5;111m'
WHITE='\e[97m'
GREEN='\e[38;5;114m'
RED='\e[38;5;167m'
YELLOW='\e[38;5;222m'
NC='\e[0m'

if ! [ -x "$(command -v curl)" ]; then
    echo -e "${RED}* Error: curl is required in order for this script to work.${NC}"
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
    local title="SAPURAHOST - THEME AUTO INSTALLER"
    local release="Script Release: ${SCRIPT_RELEASE}"

    local pad_title=$(( (width - ${#title}) / 2 ))
    local pad_rel=$(( (width - ${#release}) / 2 ))

    clear
    echo -e "${SOFT_BLUE}(——)------------------------------------------------------------------------------------------------------------------------------------------(——)${NC}"
    echo -e "${SOFT_BLUE}|  |$(printf '%*s' $width "")|  |${NC}"   
    echo -ne "${SOFT_BLUE}|  |${WHITE}"
    printf "%*s%s%*s" $pad_title "" "$title" $((width - pad_title - ${#title})) ""
    echo -e "${SOFT_BLUE}|  |${NC}"    
    echo -ne "${SOFT_BLUE}|  |${SOFT_BLUE}"
    printf "%*s%s%*s" $pad_rel "" "$release" $((width - pad_rel - ${#release})) ""
    echo -e "${SOFT_BLUE}|  |${NC}"    
    echo -e "${SOFT_BLUE}|  |$(printf '%*s' $width "")|  |${NC}"
    echo -e "${SOFT_BLUE}(——)------------------------------------------------------------------------------------------------------------------------------------------(——)${NC}"
    echo ""
}


execute_action() {
    local action=$1
    echo -e "\n\n* SapuraHost-Installer $(date) - Action: $action \n\n" >>$LOG_PATH

    case $action in
        "install_reviactyl")
            output "Memulai Instalasi Tema Reviactyl..."
            cd /var/www/pterodactyl || exit
            output "Mengamankan konfigurasi .env..."
            cp .env /root/.env_backup >>$LOG_PATH 2>&1
            
            output "Membersihkan direktori lama..."
            rm -rf * >>$LOG_PATH 2>&1
            mv /root/.env_backup .env
            
            output "Mengunduh file tema Reviactyl..."
            curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
            
            output "Membangun sistem dependensi (ini mungkin memakan waktu)..."
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            php artisan migrate --seed --force >>$LOG_PATH 2>&1
            finalize
            ;;
            
        "install_nook")
            output "Memulai Instalasi Tema Nookure..."
            cd /var/www/pterodactyl || exit
            
            output "Memasukkan panel ke mode maintenance..."
            php artisan down >>$LOG_PATH 2>&1
            
            output "Mengunduh dan mengekstrak file tema Nookure..."
            curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv >>$LOG_PATH 2>&1
            
            output "Menyesuaikan perizinan file..."
            chmod -R 755 storage/* bootstrap/cache >>$LOG_PATH 2>&1
            
            output "Menjalankan Composer..."
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            
            output "Membersihkan cache sistem..."
            php artisan view:clear >>$LOG_PATH 2>&1
            php artisan config:clear >>$LOG_PATH 2>&1
            
            output "Menjalankan migrasi database..."
            php artisan migrate --seed --force >>$LOG_PATH 2>&1
            
            output "Mengembalikan panel online..."
            php artisan queue:restart >>$LOG_PATH 2>&1
            php artisan up >>$LOG_PATH 2>&1
            finalize
            ;;
            
        "uninstall")
            output "Mengembalikan Panel ke Tema Default..."
            cd /var/www/pterodactyl || exit
            
            output "Mengamankan konfigurasi .env..."
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
    output "Mengatur kepemilikan file (www-data)..."
    chown -R www-data:www-data /var/www/pterodactyl/* >>$LOG_PATH 2>&1
    
    output "Merestart layanan (Nginx & PteroQ)..."
    systemctl restart pteroq.service >>$LOG_PATH 2>&1
    systemctl restart nginx >>$LOG_PATH 2>&1
    
    echo -e "\n${GREEN}✦ Proses selesai dengan sukses!${NC}"
    echo -e "${SOFT_BLUE}✦ Log instalasi dapat dilihat di: ${LOG_PATH}${NC}\n"
}

# Logic Menu
welcome
while true; do
    options=(
        "Install Tema Reviactyl"
        "Install Tema Nookure"
        "Uninstall Tema (Kembali ke Default)"
        "Keluar dari Installer"
    )
    actions=(
        "install_reviactyl"
        "install_nook"
        "uninstall"
        "exit"
    )

    output "Pilih Menu Eksekusi:"
    for i in "${!options[@]}"; do
        echo -e "  ${SOFT_BLUE}[$i]${NC} ${WHITE}${options[$i]}${NC}"
    done
    echo ""

    echo -ne "${YELLOW}✦ Masukkan pilihan (0-$((${#actions[@]} - 1))): ${NC}"
    read -r action

    if [ -z "$action" ] || [[ ! "0 1 2 3" =~ $action ]]; then
        error "Pilihan tidak valid, silakan coba lagi.\n"
        continue
    fi

    if [ "$action" == "3" ]; then
        output "Keluar dari installer. Terima kasih!"
        exit 0
    fi

    execute_action "${actions[$action]}"
    break
done
