#!/bin/bash
set -e

export SCRIPT_RELEASE="v1.2.0"
LOG_PATH="/var/log/sapurahost-installer.log"

SOFT_BLUE='\e[38;5;111m'
WHITE='\e[97m'
GREEN='\e[38;5;114m'
RED='\e[38;5;167m'
YELLOW='\e[38;5;222m'
NC='\e[0m'

if ! [ -x "$(command -v curl)" ]; then
    echo -e "${RED}✦ ERROR: curl is required in order for this script to work.${NC}"
    exit 1
fi

output() {
    echo -e "${SOFT_BLUE}✦${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}✦ ERROR:${NC} ${WHITE}$1${NC}"
}

run_loading() {
    local msg="$1"
    shift
    printf "${SOFT_BLUE}✦${NC} ${WHITE}%s... ${NC}" "$msg"
    "$@" >>$LOG_PATH 2>&1 &
    local pid=$!
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while kill -0 $pid 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r${SOFT_BLUE}✦${NC} ${WHITE}%s... ${SOFT_BLUE}%s${NC}" "$msg" "$frame"
            sleep 0.1
        done
    done
    wait $pid
    printf "\r${SOFT_BLUE}✦${NC} ${WHITE}%s... ${GREEN}Selesai!${NC} \n" "$msg"
}

welcome() {
    clear
    echo -e "${SOFT_BLUE}╔═══╦═══╦═══╗${NC}"
    echo -e "${SOFT_BLUE}║╔═╗║╔═╗║╔═╗║${NC}          ${WHITE}⃟Script Installer Otomatis${NC}"
    echo -e "${SOFT_BLUE}║╚══╣╚═╝║╚═╝║${NC}          ${SOFT_BLUE}────${NC}"
    echo -e "${SOFT_BLUE}╚══╗║╔══╣╔╗╔╝${NC}          ${WHITE}• Telegram: @rmddz${NC}"
    echo -e "${SOFT_BLUE}║╚═╝║║──║║║╚╗${NC}          ${WHITE}• Website: romadzrbg.my.id${NC}"
    echo -e "${SOFT_BLUE}╚═══╩╝──╚╝╚═╝${NC}"
    echo -e ""
    echo -e "       ${YELLOW}Copyright [©] Romadz Store ID – 2026${NC}"
    echo -e ""
}

execute_action() {
    local action=$1
    echo -e "\n\n* SapuraHost-Installer $(date) - Action: $action \n\n" >>$LOG_PATH

    case $action in
        "reset_password")
            NEW_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
            
            run_loading "Menghasilkan Password Random Baru" sleep 1
            run_loading "Menerapkan password baru ke user root" bash -c "echo 'root:$NEW_PASS' | chpasswd"
            
            echo -e "\n${SOFT_BLUE}✦ DATA LOGIN VPS NEW${NC}"
            echo -e " ${SOFT_BLUE}➪${NC} ${WHITE}Username VPS:${NC} ${GREEN}root${NC}"
            echo -e " ${SOFT_BLUE}➪${NC} ${WHITE}New Password:${NC} ${YELLOW}$NEW_PASS${NC}\n"
            ;;

        "install_reviactyl")
            output "Memulai Instalasi Tema Reviactyl..."
            cd /var/www/pterodactyl || exit
            run_loading "Mengamankan konfigurasi .env" cp .env /root/.env_backup
            run_loading "Membersihkan direktori lama" rm -rf *
            mv /root/.env_backup .env
            run_loading "Mengunduh file tema Reviactyl" curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz
            run_loading "Mengekstrak file tema" tar -xzvf panel.tar.gz
            rm panel.tar.gz
            run_loading "Membangun sistem dependensi" bash -c "chmod -R 755 storage/* bootstrap/cache/ && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_loading "Migrasi database" php artisan migrate --seed --force
            finalize
            ;;
            
        "install_nook")
            output "Memulai Instalasi Tema Nookure..."
            cd /var/www/pterodactyl || exit
            run_loading "Mematikan panel sementara" php artisan down
            run_loading "Mengunduh & Mengekstrak Nookure" bash -c "curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv"
            run_loading "Mengatur perizinan file" chmod -R 755 storage/* bootstrap/cache
            run_loading "Membangun sistem dependensi" bash -c "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_loading "Membersihkan cache view & config" bash -c "php artisan view:clear && php artisan config:clear"
            run_loading "Migrasi database" php artisan migrate --seed --force
            run_loading "Restart antrean & panel" bash -c "php artisan queue:restart && php artisan up"
            finalize
            ;;
            
        "uninstall")
            output "Mengembalikan Tema Default..."
            cd /var/www/pterodactyl || exit
            run_loading "Mengamankan konfigurasi .env" cp .env /root/.env_backup
            run_loading "Membersihkan direktori" rm -rf *
            mv /root/.env_backup .env
            run_loading "Mengunduh file tema Default" curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
            run_loading "Mengekstrak file tema" tar -xzvf panel.tar.gz
            rm panel.tar.gz
            run_loading "Membangun sistem dependensi" bash -c "chmod -R 755 storage/* bootstrap/cache/ && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_loading "Membersihkan cache" bash -c "php artisan view:clear && php artisan config:clear"
            finalize
            ;;
    esac
}

finalize() {
    run_loading "Mengatur kepemilikan file (www-data)" chown -R www-data:www-data /var/www/pterodactyl/*
    run_loading "Restart service pteroq" systemctl restart pteroq.service
    run_loading "Restart service nginx" systemctl restart nginx
    echo -e "\n${GREEN}✦ Proses selesai dengan sukses!${NC}"
    echo -e "${SOFT_BLUE}✦ Log instalasi dapat dilihat di: ${LOG_PATH}${NC}\n"
}

welcome
while true; do
    options=(
        "Reset & Auto-Generate Password VPS (Root)"
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
        output "Keluar dari installer. Terimakasih!"
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
