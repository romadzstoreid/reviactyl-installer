#!/bin/bash
set -e

export SCRIPT_RELEASE="v1.2.0"
LOG_PATH="/var/log/sapurahost-installer.log"

CYAN='\e[38;5;51m'
MAGENTA='\e[38;5;207m'
GREEN='\e[38;5;84m'
RED='\e[38;5;196m'
YELLOW='\e[38;5;226m'
WHITE='\e[97m'
BOLD='\e[1m'
NC='\e[0m'

if ! [ -x "$(command -v curl)" ]; then
    echo -e "${RED}✖ Error: curl is required in order for this script to work.${NC}"
    exit 1
fi

output() {
    echo -e "${CYAN}➜${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}✖ ERROR:${NC} ${WHITE}$1${NC}"
}

success() {
    echo -e "${GREEN}✔ SUCCESS:${NC} ${WHITE}$1${NC}"
}

run_with_spinner() {
    local msg="$1"
    local cmd="$2"
    
    echo -ne "${CYAN}➜${NC} ${WHITE}${msg}... ${NC}"
    
    eval "$cmd" >>$LOG_PATH 2>&1 &
    local pid=$!
    
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}➜${NC} ${WHITE}${msg}... ${MAGENTA}${spin:$i:1}${NC}"
        sleep 0.1
    done
    
    wait $pid
    local exit_status=$?
    
    if [ $exit_status -eq 0 ]; then
        printf "\r${GREEN}✔${NC} ${WHITE}${msg}... ${GREEN}Selesai!${NC}      \n"
    else
        printf "\r${RED}✖${NC} ${WHITE}${msg}... ${RED}Gagal!${NC}        \n"
        echo -e "${RED}Silakan cek log di ${LOG_PATH} untuk melihat error detailnya.${NC}"
        exit 1
    fi
}

welcome() {
    local width=60
    local title="SAPURAHOST - THEME AUTO INSTALLER"
    local release="Script Release: ${SCRIPT_RELEASE}"

    local pad_title=$(( (width - ${#title}) / 2 ))
    local pad_rel=$(( (width - ${#release}) / 2 ))

    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│$(printf '%*s' $width "")│${NC}"   
    
    echo -ne "${CYAN}│${BOLD}${WHITE}"
    printf "%*s%s%*s" $pad_title "" "$title" $((width - pad_title - ${#title})) ""
    echo -e "${NC}${CYAN}│${NC}"    
    
    echo -ne "${CYAN}│${MAGENTA}"
    printf "%*s%s%*s" $pad_rel "" "$release" $((width - pad_rel - ${#release})) ""
    echo -e "${NC}${CYAN}│${NC}"    
    
    echo -e "${CYAN}│$(printf '%*s' $width "")│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

execute_action() {
    local action=$1
    echo -e "\n\n* SapuraHost-Installer $(date) - Action: $action \n\n" >>$LOG_PATH

    case $action in
        "reset_password")
            output "Menghasilkan Password Random Baru..."
            NEW_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 14)
            
            run_with_spinner "Menerapkan password baru ke user root" "echo 'root:$NEW_PASS' | chpasswd"
            
            local width=60
            local line1="DATA LOGIN VPS BARU (ROOT)"
            local pad1=$(( (width - ${#line1}) / 2 ))

            echo -e "\n${GREEN}╭────────────────────────────────────────────────────────────╮${NC}"           
            echo -ne "${GREEN}│${BOLD}${WHITE}"
            printf "%*s%s%*s" $pad1 "" "$line1" $((width - pad1 - ${#line1})) ""
            echo -e "${NC}${GREEN}│${NC}"
            echo -e "${GREEN}├────────────────────────────────────────────────────────────┤${NC}"          
            echo -e "${GREEN}│${WHITE}   Username : ${BOLD}root${NC}$(printf '%*s' 31 "")${GREEN}│${NC}"
            echo -e "${GREEN}│${WHITE}   Password : ${YELLOW}${BOLD}$NEW_PASS${NC}$(printf '%*s' $((45 - ${#NEW_PASS})) "")${GREEN}│${NC}"
            echo -e "${GREEN}╰────────────────────────────────────────────────────────────╯${NC}"
            ;;

        "install_reviactyl")
            output "Memulai Instalasi Tema Reviactyl..."
            cd /var/www/pterodactyl || exit
            
            run_with_spinner "Mengamankan konfigurasi .env" "cp .env /root/.env_backup"
            run_with_spinner "Membersihkan direktori lama" "rm -rf *"
            mv /root/.env_backup .env
            
            run_with_spinner "Mengunduh file tema Reviactyl" "curl -Lo panel.tar.gz https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz && tar -xzvf panel.tar.gz && rm panel.tar.gz"
            run_with_spinner "Mengatur perizinan file" "chmod -R 755 storage/* bootstrap/cache/"
            run_with_spinner "Menginstal dependensi Composer" "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_with_spinner "Melakukan migrasi database" "php artisan migrate --seed --force"
            finalize
            ;;
            
        "install_nook")
            output "Memulai Instalasi Tema Nookure..."
            cd /var/www/pterodactyl || exit
            
            run_with_spinner "Mengaktifkan mode maintenance" "php artisan down"
            run_with_spinner "Mengunduh file tema Nookure" "curl -L https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz | tar -xzv"
            run_with_spinner "Mengatur perizinan file" "chmod -R 755 storage/* bootstrap/cache"
            run_with_spinner "Menginstal dependensi Composer" "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_with_spinner "Membersihkan cache sistem" "php artisan view:clear && php artisan config:clear"
            run_with_spinner "Melakukan migrasi database" "php artisan migrate --seed --force"
            run_with_spinner "Me-restart queue worker" "php artisan queue:restart"
            run_with_spinner "Menonaktifkan mode maintenance" "php artisan up"
            finalize
            ;;
            
        "uninstall")
            output "Mengembalikan Panel ke Tema Default..."
            cd /var/www/pterodactyl || exit
            
            run_with_spinner "Mengamankan konfigurasi .env" "cp .env /root/.env_backup"
            run_with_spinner "Membersihkan direktori lama" "rm -rf *"
            mv /root/.env_backup .env
            
            run_with_spinner "Mengunduh panel default Pterodactyl" "curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz && tar -xzvf panel.tar.gz && rm panel.tar.gz"
            run_with_spinner "Mengatur perizinan file" "chmod -R 755 storage/* bootstrap/cache/"
            run_with_spinner "Menginstal dependensi Composer" "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
            run_with_spinner "Membersihkan cache sistem" "php artisan view:clear && php artisan config:clear"
            finalize
            ;;
    esac
}

finalize() {
    run_with_spinner "Mengatur kepemilikan file web (www-data)" "chown -R www-data:www-data /var/www/pterodactyl/*"
    run_with_spinner "Me-restart service Pterodactyl & Nginx" "systemctl restart pteroq.service && systemctl restart nginx"
    
    echo ""
    success "Semua proses selesai dengan sukses!"
    echo -e "${CYAN}➜${NC} Log detail instalasi tersimpan di: ${WHITE}${LOG_PATH}${NC}\n"
}

while true; do
    welcome
    
    echo -e "${BOLD}${WHITE}  Pilih Menu Eksekusi:${NC}\n"
    
    echo -e "${CYAN}  ╭─[ Manajemen Sistem ]${NC}"
    echo -e "${CYAN}  │${NC}  ${MAGENTA}[1]${NC} Reset & Auto-Generate Password VPS (Root)"
    echo -e "${CYAN}  │${NC}"
    echo -e "${CYAN}  ├─[ Instalasi Tema Pterodactyl ]${NC}"
    echo -e "${CYAN}  │${NC}  ${MAGENTA}[2]${NC} Install Tema Reviactyl"
    echo -e "${CYAN}  │${NC}  ${MAGENTA}[3]${NC} Install Tema Nookure"
    echo -e "${CYAN}  │${NC}"
    echo -e "${CYAN}  ├─[ Maintenance & Keluar ]${NC}"
    echo -e "${CYAN}  │${NC}  ${MAGENTA}[4]${NC} Uninstall Tema (Kembali ke Default)"
    echo -e "${CYAN}  │${NC}  ${MAGENTA}[0]${NC} Keluar dari Installer"
    echo -e "${CYAN}  ╰────────────────────────────────────────${NC}\n"

    echo -ne "${YELLOW}  ➜ Masukkan pilihan Anda [0-4]: ${NC}"
    read -r action

    echo 

    case $action in
        1) 
            execute_action "reset_password"
            echo -ne "\n${YELLOW}Tekan [Enter] untuk kembali ke menu...${NC}"
            read -r
            ;;
        2) 
            execute_action "install_reviactyl"
            echo -ne "\n${YELLOW}Tekan [Enter] untuk kembali ke menu...${NC}"
            read -r
            ;;
        3) 
            execute_action "install_nook"
            echo -ne "\n${YELLOW}Tekan [Enter] untuk kembali ke menu...${NC}"
            read -r
            ;;
        4) 
            execute_action "uninstall"
            echo -ne "\n${YELLOW}Tekan [Enter] untuk kembali ke menu...${NC}"
            read -r
            ;;
        0) 
            output "Keluar dari installer. Terima kasih telah menggunakan layanan kami!"
            echo ""
            exit 0
            ;;
        *) 
            error "Pilihan tidak valid, silakan masukkan angka 0-4."
            sleep 2
            ;;
    esac
done
