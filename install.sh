#!/bin/bash
set -e

export SCRIPT_RELEASE="v1.2"
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
        "reset_password")
            output "Menghasilkan Password Random Baru..."
            NEW_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
            
            output "Menerapkan password baru ke user root..."
            echo "root:$NEW_PASS" | chpasswd
            
            local width=60
            local line1="DATA LOGIN VPS BARU (ROOT)"
            local line2="Username : root"
            local line3="Password : $NEW_PASS"

            local pad1=$(( (width - ${#line1}) / 2 ))
            local pad2=$(( (width - ${#line2}) / 2 ))
            local pad3=$(( (width - ${#line3}) / 2 ))

            echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
            echo -ne "${GREEN}║${WHITE}"
            printf "%*s%s%*s" $pad1 "" "$line1" $((width - pad1 - ${#line1})) ""
            echo -e "${GREEN}║${NC}"
            echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"            
            echo -ne "${GREEN}║${WHITE}"
            printf "%*s%s%*s" $pad2 "" "$line2" $((width - pad2 - ${#line2})) ""
            echo -e "${GREEN}║${NC}"            
            echo -ne "${GREEN}║${WHITE}"
            printf "%*s%s%*s" $pad3 "" "Username : root" $((width - pad2 - ${#line2})) ""
            echo -e "\r${GREEN}║${WHITE}$(printf '%*s' $pad3 "")${WHITE}Password : ${YELLOW}$NEW_PASS${WHITE}$(printf '%*s' $((width - pad3 - ${#line3})) "")${GREEN}║${NC}"

            echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${RED}[ ! ] Simpan password dengan Aman.${NC}\n"
            ;;


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
            
            output "Membangun sistem dependensi..."
            chmod -R 755 storage/* bootstrap/cache/
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            php artisan migrate --seed --force >>$LOG_PATH 2>&1
            finalize
            ;;
            
        "install_nook")
            output "Memulai Instalasi Tema Nookure..."
            cd /var/www/pterodactyl || exit
            php artisan down >>$LOG_PATH 2>&1
            curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv >>$LOG_PATH 2>&1
            chmod -R 755 storage/* bootstrap/cache >>$LOG_PATH 2>&1
            COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader >>$LOG_PATH 2>&1
            php artisan view:clear >>$LOG_PATH 2>&1
            php artisan config:clear >>$LOG_PATH 2>&1
            php artisan migrate --seed --force >>$LOG_PATH 2>&1
            php artisan queue:restart >>$LOG_PATH 2>&1
            php artisan up >>$LOG_PATH 2>&1
            finalize
            ;;
            
        "uninstall")
            output "Mengembalikan Panel ke Tema Default..."
            cd /var/www/pterodactyl || exit
            cp .env /root/.env_backup >>$LOG_PATH 2>&1
            rm -rf * >>$LOG_PATH 2>&1
            mv /root/.env_backup .env
            curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >>$LOG_PATH 2>&1
            tar -xzvf panel.tar.gz >>$LOG_PATH 2>&1
            rm panel.tar.gz
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
    systemctl restart pteroq.service >>$LOG_PATH 2>&1
    systemctl restart nginx >>$LOG_PATH 2>&1
    echo -e "\n${GREEN}✦ Proses selesai dengan sukses!${NC}"
    echo -e "${SOFT_BLUE}✦ Log instalasi dapat dilihat di: ${LOG_PATH}${NC}\n"
}

welcome
while true; do
    options=(
        "Reset Password VPS"
        "Install Tema Reviactyl"
        "Install Tema Nookure"
        "Uninstall Tema (Kembali ke Default)"
        "Keluar dari Installer"
    )
    actions=(
        "reset_password"
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

    if [[ ! "$action" =~ ^[0-4]$ ]]; then
        error "Pilihan tidak valid, silakan masukkan angka 0-4.\n"
        continue
    fi

    if [ "$action" == "4" ]; then
        output "Keluar dari installer. Terima kasih!"
        exit 0
    fi

    execute_action "${actions[$action]}"
    
    if [ "$action" == "0" ]; then
        echo -ne "${YELLOW}Tekan [Enter] untuk kembali ke menu...${NC}"
        read -r
        welcome
        continue
    fi
    
    break
done
