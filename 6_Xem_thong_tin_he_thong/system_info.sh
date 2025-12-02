#!/usr/bin/env bash

# Module Xem thông tin hệ thống
# Chứa các hàm hiển thị thông tin về hệ thống, Docker, N8N

show_system_info() {
    echo -e "${CYAN}💻 THÔNG TIN HỆ THỐNG${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BOLD}${GREEN}🖥️  HỆ ĐIỀU HÀNH & PHẦN CỨNG${NC}"
    echo -e "${GREEN}   • Hệ điều hành:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    echo -e "${GREEN}   • Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}   • Kiến trúc:${NC} $(uname -m)"
    echo -e "${GREEN}   • RAM:${NC} $(free -h | awk '/^Mem:/ {print $2}') (Đã dùng: $(free -h | awk '/^Mem:/ {print $3}'))"
    echo -e "${GREEN}   • Disk:${NC} $(df -h / | awk '/\// {print $2}') (Đã dùng: $(df -h / | awk '/\// {print $3}'))"
    echo -e "${GREEN}   • CPU:${NC} $(nproc) cores"
    echo -e "${GREEN}   • Uptime:${NC} $(uptime -p 2>/dev/null || uptime | awk '{print $3, $4}')"
    
    echo ""
    echo -e "${BOLD}${CYAN}🌐 THÔNG TIN MẠNG${NC}"
    local ipv4=$(get_server_ipv4)
    local ipv6=$(get_server_ipv6)
    
    if [ -n "$ipv4" ] && [ -n "$ipv6" ]; then
        echo -e "${CYAN}   • IPv4:${NC} $ipv4"
        echo -e "${CYAN}   • IPv6:${NC} $ipv6"
        echo -e "${PURPLE}   • Loại kết nối:${NC} Dual-stack (IPv4 + IPv6)"
    elif [ -n "$ipv4" ]; then
        echo -e "${CYAN}   • IPv4:${NC} $ipv4"
        echo -e "${YELLOW}   • IPv6:${NC} Không có"
        echo -e "${PURPLE}   • Loại kết nối:${NC} IPv4 only"
    elif [ -n "$ipv6" ]; then
        echo -e "${YELLOW}   • IPv4:${NC} Không có"
        echo -e "${CYAN}   • IPv6:${NC} $ipv6"
        echo -e "${PURPLE}   • Loại kết nối:${NC} IPv6 only"
    else
        echo -e "${RED}   ❌ Không phát hiện được IP${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${BLUE}🐳 DOCKER${NC}"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        echo -e "${GREEN}   • Version:${NC} $docker_version"
        
        if docker info &>/dev/null 2>&1; then
            echo -e "${GREEN}   • Status:${NC} ✅ Đang chạy"
            
            if [ -f "/etc/docker/daemon.json" ] && grep -q '"ipv6".*true' /etc/docker/daemon.json 2>/dev/null; then
                echo -e "${CYAN}   • IPv6:${NC} ✅ Đã kích hoạt"
            else
                echo -e "${CYAN}   • IPv6:${NC} ❌ Chưa kích hoạt"
            fi
            
            local containers_running=$(docker ps -q | wc -l)
            local containers_total=$(docker ps -a -q | wc -l)
            echo -e "${GREEN}   • Containers:${NC} $containers_running running / $containers_total total"
            
            local images_count=$(docker images -q | wc -l)
            echo -e "${GREEN}   • Images:${NC} $images_count"
            
            if command -v docker-compose &> /dev/null; then
                local compose_version=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
                echo -e "${GREEN}   • Docker Compose:${NC} $compose_version"
            fi
        else
            echo -e "${YELLOW}   • Status:${NC} ⚠️ Không chạy"
        fi
    else
        echo -e "${RED}   ❌ Docker chưa được cài đặt${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${PURPLE}📦 N8N${NC}"
    if [ -f "$N8N_DATA_DIR/docker-compose.yml" ]; then
        echo -e "${GREEN}   • Thư mục data:${NC} $N8N_DATA_DIR"
        
        if docker ps --format "{{.Names}}" | grep -q "^n8n$"; then
            echo -e "${GREEN}   • Status:${NC} ✅ Đang chạy"
            
            local n8n_version=$(docker exec n8n n8n --version 2>/dev/null | grep -o 'n8n@[0-9.]*' || echo "Unknown")
            echo -e "${GREEN}   • Version:${NC} $n8n_version"
            
            local n8n_uptime=$(docker ps --filter "name=n8n" --format "{{.Status}}" 2>/dev/null)
            echo -e "${GREEN}   • Uptime:${NC} $n8n_uptime"
        else
            echo -e "${YELLOW}   • Status:${NC} ⚠️ Không chạy"
        fi
        
        # Sử dụng hàm chuẩn từ domain_manager để đọc domain
        local domain=""
        if type get_current_domain &>/dev/null; then
            domain=$(get_current_domain)
        fi
        
        if [ -n "$domain" ]; then
            echo -e "${GREEN}   • Domain:${NC} $domain"
            
            if [ -d "/etc/letsencrypt/live/$domain" ]; then
                local ssl_expiry=$(sudo certbot certificates 2>/dev/null | grep -A 2 "$domain" | grep "Expiry Date" | awk '{print $3, $4, $5}' || echo "N/A")
                echo -e "${GREEN}   • SSL:${NC} ✅ Đã cài đặt (hết hạn: $ssl_expiry)"
            else
                echo -e "${YELLOW}   • SSL:${NC} ❌ Chưa cài đặt"
            fi
        fi
        
        if docker ps --format "{{.Names}}" | grep -q "postgres"; then
            echo -e "${GREEN}   • Database:${NC} PostgreSQL"
            
            if docker ps --filter "name=postgres" --format "{{.Status}}" | grep -q "Up"; then
                echo -e "${GREEN}   • DB Status:${NC} ✅ Đang chạy"
            else
                echo -e "${YELLOW}   • DB Status:${NC} ⚠️ Không chạy"
            fi
        fi
    else
        echo -e "${YELLOW}   ⚠️ N8N chưa được cài đặt${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}💾 BACKUP${NC}"
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${GREEN}   • Thư mục backup:${NC} $BACKUP_DIR"
        
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        local backup_count=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" 2>/dev/null | wc -l)
        
        if [ $backup_count -gt 0 ]; then
            echo -e "${GREEN}   • Số lượng backup:${NC} $backup_count files"
            echo -e "${GREEN}   • Tổng dung lượng:${NC} $backup_size"
            
            local latest_backup=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
            if [ -n "$latest_backup" ]; then
                local latest_date=$(stat -c %y "$latest_backup" 2>/dev/null | cut -d'.' -f1)
                echo -e "${GREEN}   • Backup mới nhất:${NC} $latest_date"
            fi
        else
            echo -e "${YELLOW}   • Số lượng backup:${NC} 0 files"
        fi
    else
        echo -e "${YELLOW}   ⚠️ Thư mục backup chưa được tạo${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${RED}🔧 NGINX${NC}"
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
        echo -e "${GREEN}   • Version:${NC} $nginx_version"
        
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}   • Status:${NC} ✅ Đang chạy"
        else
            echo -e "${YELLOW}   • Status:${NC} ⚠️ Không chạy"
        fi
        
        if [ -f "/etc/nginx/sites-available/n8n" ]; then
            echo -e "${GREEN}   • Config n8n:${NC} ✅ Đã cấu hình"
        else
            echo -e "${YELLOW}   • Config n8n:${NC} ❌ Chưa cấu hình"
        fi
    else
        echo -e "${RED}   ❌ Nginx chưa được cài đặt${NC}"
    fi
}

show_detailed_info() {
    clear
    print_banner
    
    echo -e "${BOLD}${CYAN}📊 THÔNG TIN CHI TIẾT HỆ THỐNG${NC}"
    echo ""
    
    show_system_info
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW}💡 Gợi ý:${NC}"
    echo -e "${WHITE}   • Sử dụng menu 'Quản lý Docker' để xem chi tiết containers${NC}"
    echo -e "${WHITE}   • Sử dụng menu 'Quản lý Backup' để quản lý backup${NC}"
    echo -e "${WHITE}   • Sử dụng menu 'Quản lý SSL' để kiểm tra SSL${NC}"
}
