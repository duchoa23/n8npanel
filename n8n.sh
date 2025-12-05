#!/usr/bin/env bash

readonly SCRIPT_ARCHITECTURE="modular"
readonly MANIFEST_URL="https://duchoa.biz/test/manifest.json"

# Đọc version từ manifest.json local (sẽ được set sau khi INSTALL_DIR được định nghĩa)
SCRIPT_VERSION="3.0"
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly WHITE='\033[1;37m'

# Thư mục cài đặt panel - resolve symlink để lấy đường dẫn thực
SCRIPT_PATH="${BASH_SOURCE[0]}"

# Resolve symlink nếu có
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Ưu tiên dùng /opt/n8npanel/v3 nếu tồn tại, nếu không thì dùng SCRIPT_DIR (dev mode)
if [ -d "/opt/n8npanel/v3" ] && [ -f "/opt/n8npanel/v3/n8n.sh" ]; then
    INSTALL_DIR="/opt/n8npanel/v3"
else
    INSTALL_DIR="$SCRIPT_DIR"
fi

# Thư mục log tập trung
LOG_DIR="/var/log/n8npanel"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="$LOG_DIR/n8n_panel.log"

N8N_DATA_DIR="/root/n8n_data"
COMPOSE_FILE="$N8N_DATA_DIR/docker-compose.yml"
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
BACKUP_DIR="$N8N_DATA_DIR/backups"

# Export các biến quan trọng để các wrapper scripts có thể sử dụng
export INSTALL_DIR
export N8N_DATA_DIR
export COMPOSE_FILE
export BACKUP_DIR
export LOG_FILE
export LOG_DIR

# Danh sách thư mục bắt buộc cho v3
readonly REQUIRED_DIRECTORIES=(
    "common"
    "1_Cai_dat_n8n_moi"
    "2_Quan_ly_Backup"
    "3_Quan_ly_SSL"
    "4_Quan_ly_Docker_Container"
    "5_Quan_ly_N8N"
    "6_Xem_thong_tin_he_thong"
    "7_Cap_nhat"
    "8_Multi_Instance"
    "9_Go_cai_dat"
)

# Danh sách file bắt buộc
readonly REQUIRED_FILES=(
    "n8n.sh"
    "common/utils.sh"
    "common/network.sh"
    "common/nginx_manager.sh"
    "common/ssl_manager.sh"
    "common/env_manager.sh"
    "common/domain_manager.sh"
    "common/restart_manager.sh"
    "common/instance_selector.sh"
    "common/domain_change_wrapper.sh"
    "common/nginx_config_wrapper.sh"
    "common/ssl_install_wrapper.sh"
    "1_Cai_dat_n8n_moi/install.sh"
    "2_Quan_ly_Backup/backup.sh"
    "3_Quan_ly_SSL/ssl.sh"
    "4_Quan_ly_Docker_Container/docker.sh"
    "5_Quan_ly_N8N/manage.sh"
    "6_Xem_thong_tin_he_thong/system_info.sh"
    "7_Cap_nhat/update.sh"
    "8_Multi_Instance/multi_instance.sh"
    "9_Go_cai_dat/uninstall.sh"
)

# Đọc version từ manifest.json sau khi INSTALL_DIR đã được set
if [ -f "$INSTALL_DIR/manifest.json" ] && command -v jq >/dev/null 2>&1; then
    SCRIPT_VERSION=$(jq -r '.version' "$INSTALL_DIR/manifest.json" 2>/dev/null || echo "3.0")
fi
readonly SCRIPT_VERSION

# Source các common functions (THỨ TỰ QUAN TRỌNG - không thay đổi!)
# 1. utils.sh - Các hàm cơ bản (log_message, check_error) - BẮT BUỘC
if [ -f "$INSTALL_DIR/common/utils.sh" ]; then
    source "$INSTALL_DIR/common/utils.sh"
else
    echo -e "\033[0;31m❌ CRITICAL: utils.sh không tồn tại!\033[0m"
    exit 1
fi

# 2. network.sh - Các hàm network (get_server_ip, check_domain_ip)
if [ -f "$INSTALL_DIR/common/network.sh" ]; then
    source "$INSTALL_DIR/common/network.sh"
else
    log_message "WARNING" "network.sh không tồn tại, một số tính năng có thể không hoạt động"
fi

# 3. ssl_manager.sh - Quản lý SSL (PHẢI trước nginx_manager vì nginx cần check_ssl_exists)
if [ -f "$INSTALL_DIR/common/ssl_manager.sh" ]; then
    source "$INSTALL_DIR/common/ssl_manager.sh"
else
    log_message "WARNING" "ssl_manager.sh không tồn tại"
fi

# 4. nginx_manager.sh - Quản lý Nginx (cần ssl_manager đã load)
if [ -f "$INSTALL_DIR/common/nginx_manager.sh" ]; then
    source "$INSTALL_DIR/common/nginx_manager.sh"
else
    log_message "WARNING" "nginx_manager.sh không tồn tại"
fi

# 5. env_manager.sh - Quản lý .env file
if [ -f "$INSTALL_DIR/common/env_manager.sh" ]; then
    source "$INSTALL_DIR/common/env_manager.sh"
else
    log_message "WARNING" "env_manager.sh không tồn tại"
fi

# 6. restart_manager.sh - Quản lý restart container
if [ -f "$INSTALL_DIR/common/restart_manager.sh" ]; then
    source "$INSTALL_DIR/common/restart_manager.sh"
else
    log_message "WARNING" "restart_manager.sh không tồn tại"
fi

# 7. domain_manager.sh - Quản lý domain (cần tất cả module trên)
if [ -f "$INSTALL_DIR/common/domain_manager.sh" ]; then
    source "$INSTALL_DIR/common/domain_manager.sh"
else
    log_message "WARNING" "domain_manager.sh không tồn tại"
fi

# 8. instance_selector.sh - Chọn instance cho multi-instance support
if [ -f "$INSTALL_DIR/common/instance_selector.sh" ]; then
    source "$INSTALL_DIR/common/instance_selector.sh"
else
    log_message "WARNING" "instance_selector.sh không tồn tại"
fi

# Trap handler tập trung - gọi tất cả cleanup functions
_global_cleanup() {
    # Gọi các cleanup functions nếu tồn tại
    type _nginx_cleanup &>/dev/null && _nginx_cleanup
    type _ssl_cleanup &>/dev/null && _ssl_cleanup
    type _domain_cleanup &>/dev/null && _domain_cleanup
    type remove_restart_lock &>/dev/null && remove_restart_lock
}
trap _global_cleanup EXIT INT TERM

# Source các module chức năng
_source_module() {
    local module_path="$1"
    local module_name="$2"
    if [ -f "$module_path" ]; then
        source "$module_path"
    else
        log_message "WARNING" "Module $module_name không tồn tại: $module_path"
    fi
}

_source_module "$INSTALL_DIR/1_Cai_dat_n8n_moi/install.sh" "install"
_source_module "$INSTALL_DIR/2_Quan_ly_Backup/backup.sh" "backup"
_source_module "$INSTALL_DIR/3_Quan_ly_SSL/ssl.sh" "ssl"
_source_module "$INSTALL_DIR/4_Quan_ly_Docker_Container/docker.sh" "docker"
_source_module "$INSTALL_DIR/5_Quan_ly_N8N/manage.sh" "manage"
_source_module "$INSTALL_DIR/6_Xem_thong_tin_he_thong/system_info.sh" "system_info"
_source_module "$INSTALL_DIR/7_Cap_nhat/update.sh" "update"
_source_module "$INSTALL_DIR/8_Multi_Instance/multi_instance.sh" "multi_instance"
_source_module "$INSTALL_DIR/9_Go_cai_dat/uninstall.sh" "uninstall"

# Kiểm tra và tạo cấu trúc thư mục cần thiết
check_and_create_structure() {
    local missing_dirs=()
    local missing_files=()
    
    # Kiểm tra thư mục
    for dir in "${REQUIRED_DIRECTORIES[@]}"; do
        if [ ! -d "$INSTALL_DIR/$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done
    
    # Kiểm tra file
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    # Nếu có thư mục hoặc file thiếu
    if [ ${#missing_dirs[@]} -gt 0 ] || [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Phát hiện cấu trúc panel chưa đầy đủ${NC}"
        
        if [ ${#missing_dirs[@]} -gt 0 ]; then
            echo -e "${CYAN}📁 Thư mục thiếu:${NC}"
            printf '   - %s\n' "${missing_dirs[@]}"
        fi
        
        if [ ${#missing_files[@]} -gt 0 ]; then
            echo -e "${CYAN}📄 File thiếu:${NC}"
            printf '   - %s\n' "${missing_files[@]}"
        fi
        
        echo ""
        echo -e "${YELLOW}Bạn có muốn tự động tạo/tải các file thiếu không? [Y/n]:${NC}"
        read -p "" auto_fix
        
        if [[ "$auto_fix" =~ ^[Yy]$ ]] || [ -z "$auto_fix" ]; then
            # Tạo thư mục thiếu
            for dir in "${missing_dirs[@]}"; do
                mkdir -p "$INSTALL_DIR/$dir"
                echo -e "${GREEN}✅ Đã tạo thư mục: $dir${NC}"
            done
            
            # Nếu có file thiếu, gợi ý cập nhật
            if [ ${#missing_files[@]} -gt 0 ]; then
                echo -e "${CYAN}💡 Vui lòng chạy 'Cập nhật Panel' để tải các file thiếu${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Panel có thể không hoạt động đầy đủ${NC}"
        fi
    fi
}

# Cấp quyền thực thi cho tất cả file .sh
fix_permissions() {
    local fixed_count=0
    
    while IFS= read -r -d '' file; do
        if [ ! -x "$file" ]; then
            chmod +x "$file"
            ((fixed_count++))
        fi
    done < <(find "$INSTALL_DIR" -name "*.sh" -type f -print0 2>/dev/null)
    
    if [ $fixed_count -gt 0 ]; then
        echo -e "${GREEN}✅ Đã cấp quyền thực thi cho $fixed_count file${NC}"
    fi
}



# Kiểm tra cấu trúc khi khởi động
check_and_create_structure
fix_permissions

# Đảm bảo file .env tồn tại (quan trọng cho image có sẵn)
if type ensure_env_file &>/dev/null; then
    ensure_env_file
fi

# Load config khi script khởi động
if type load_config_from_env &>/dev/null; then
    load_config_from_env
fi

print_banner() {
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                           N8N AUTO INSTALLER & MANAGER v${SCRIPT_VERSION}                          ║${NC}"
    echo -e "${YELLOW}║                 Powered by iNET - https://inet.vn -  Hotline: 19009250               ║${NC}"
    echo -e "${YELLOW}║              Phiên bản hỗ trợ Ubuntu + Docker + PostgreSQL + Backup + SSL            ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_main_menu() {
    clear
    print_banner

    echo -e "${BOLD}${CYAN}                                 MENU CHÍNH${NC}"
    echo ""
    echo -e "  ${BOLD}${GREEN}CÀI ĐẶT & QUẢN LÝ${NC}                         ${BOLD}${CYAN}CÔNG CỤ & BẢO TRÌ${NC}"
    echo -e "  ${GREEN}───────────────────────${NC}                   ${CYAN}──────────────────────────${NC}"
    echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Cài đặt n8n mới (Full)       ${NC}       ${BOLD}${CYAN}5.${NC} ${WHITE}Quản lý N8N${NC}"
    echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Quản lý Backup               ${NC}       ${BOLD}${CYAN}6.${NC} ${WHITE}Xem thông tin hệ thống${NC}"
    echo -e "  ${BOLD}${GREEN}3.${NC} ${WHITE}Quản lý SSL                  ${NC}       ${BOLD}${CYAN}7.${NC} ${WHITE}Cập nhật${NC}"
    echo -e "  ${BOLD}${GREEN}4.${NC} ${WHITE}Quản lý Docker Container     ${NC}       ${BOLD}${PURPLE}8.${NC} ${WHITE}Multi-Instance N8N${NC}"
    echo ""
    echo -e "  ${BOLD}${RED}9.${NC} ${WHITE}Gỡ cài đặt${NC}                          ${BOLD}${RED}0.${NC} ${WHITE}Thoát${NC}"
    echo ""
    
    echo -e "${BOLD}${YELLOW}Mẹo:${NC} ${WHITE}Chọn số tương ứng để truy cập tính năng${NC}"
    echo ""
}

main() {
    if [[ $EUID -eq 0 ]] && [[ "$1" != "--backup" ]]; then
        echo -e "${YELLOW}⚠️  Cảnh báo: Đang chạy với quyền root. Một số tính năng có thể cần quyền user thường.${NC}"
    fi

    case "$1" in
        --help)
            echo "Sử dụng: $0 [tùy chọn]"
            echo "Tùy chọn:"
            echo "  --help             Hiển thị trợ giúp"
            exit 0
            ;;
    esac

    while true; do
        show_main_menu
        read -p "$(echo -e ${CYAN}Nhập lựa chọn [0-9]: ${NC})" choice
        
        case $choice in
            1)
                if type main_installation &>/dev/null; then
                    main_installation
                else
                    echo -e "${RED}❌ Module cài đặt chưa được load${NC}"
                fi
                read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                ;;
            2)
                if type handle_backup_menu &>/dev/null; then
                    handle_backup_menu
                else
                    echo -e "${RED}❌ Module backup chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            3)
                if type handle_ssl_menu &>/dev/null; then
                    handle_ssl_menu
                else
                    echo -e "${RED}❌ Module SSL chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            4)
                if type handle_docker_menu &>/dev/null; then
                    handle_docker_menu
                else
                    echo -e "${RED}❌ Module Docker chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            5)
                if type handle_n8n_menu &>/dev/null; then
                    handle_n8n_menu
                else
                    echo -e "${RED}❌ Module Quản lý N8N chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            6)
                if type show_detailed_info &>/dev/null; then
                    show_detailed_info
                else
                    echo -e "${RED}❌ Module System Info chưa được load${NC}"
                fi
                read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                ;;
            7)
                if type handle_update_menu &>/dev/null; then
                    handle_update_menu
                else
                    echo -e "${RED}❌ Module Cập nhật chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            8)
                if type handle_multi_instance_menu &>/dev/null; then
                    handle_multi_instance_menu
                else
                    echo -e "${RED}❌ Module Multi-Instance chưa được load${NC}"
                    read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                fi
                ;;
            9)
                if type uninstall_n8n &>/dev/null; then
                    uninstall_n8n
                else
                    echo -e "${RED}❌ Module Gỡ cài đặt chưa được load${NC}"
                fi
                read -p "$(echo -e ${YELLOW}Nhấn Enter để tiếp tục...${NC})"
                ;;
            0)
                echo -e "${GREEN}👋 Tạm biệt!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
                sleep 2
                ;;
        esac
    done
}

main "$@"
