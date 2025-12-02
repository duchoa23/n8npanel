#!/usr/bin/env bash

# Module Multi-Instance N8N
# Quản lý nhiều instance N8N trên cùng 1 VPS

# Constants
readonly BASE_N8N_PORT=5678
readonly BASE_DB_PORT=5432
readonly MAX_INSTANCES=10

# Lấy danh sách tất cả instances đang chạy
list_all_instances() {
    echo -e "${BOLD}${CYAN}📋 DANH SÁCH CÁC INSTANCE N8N${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Header
    printf "%-4s %-20s %-20s %-8s %-25s %-12s\n" "ID" "N8N Container" "DB Container" "Port" "Domain" "Status"
    echo "─────────────────────────────────────────────────────────────────────────────────────────────────"
    
    local found_any=false
    
    # Instance mặc định (1)
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
        found_any=true
        local status=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$" && echo "✅ Running" || echo "⏹️ Stopped")
        local domain=$(get_instance_domain "1")
        printf "%-4s %-20s %-20s %-8s %-25s %-12s\n" "1" "n8n" "postgres" "5678" "${domain:-localhost}" "$status"
    fi
    
    # Các instance khác (2-10) - kiểm tra cả container name và thư mục data
    for i in $(seq 2 $MAX_INSTANCES); do
        local container_name="n8n_$i"
        local data_dir="/root/n8n_data_${i}"
        local found_container=""
        local found_db=""
        
        # Tìm container n8n (có thể có prefix từ docker-compose)
        found_container=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${container_name}$|n8n_data_${i}[-_]${container_name}$|n8n_data_${i}[-_]n8n_${i}" | head -1)
        
        # Tìm container postgres
        found_db=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^postgres_${i}$|n8n_data_${i}[-_]postgres_${i}" | head -1)
        
        # Nếu tìm thấy container hoặc có thư mục data
        if [ -n "$found_container" ] || [ -d "$data_dir" ]; then
            found_any=true
            local status="⏹️ Stopped"
            
            if [ -n "$found_container" ]; then
                # Kiểm tra container có đang chạy không
                if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${found_container}$"; then
                    status="✅ Running"
                fi
            elif [ -d "$data_dir" ]; then
                status="📁 Data only"
            fi
            
            local port=$((BASE_N8N_PORT + i - 1))
            local domain=$(get_instance_domain "$i")
            
            # Hiển thị tên container thực tế hoặc expected name
            local display_n8n="${found_container:-$container_name}"
            local display_db="${found_db:-postgres_$i}"
            
            printf "%-4s %-20s %-20s %-8s %-25s %-12s\n" "$i" "$display_n8n" "$display_db" "$port" "${domain:-localhost}" "$status"
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo -e "${YELLOW}  Chưa có instance nào được cài đặt${NC}"
    fi
    
    echo ""
}

# Lấy domain của instance
get_instance_domain() {
    local instance_id="$1"
    local env_file=""
    
    if [ "$instance_id" = "1" ] || [ -z "$instance_id" ]; then
        env_file="/root/n8n_data/.env"
    else
        env_file="/root/n8n_data_${instance_id}/.env"
    fi
    
    if [ -f "$env_file" ]; then
        grep "^DOMAIN=" "$env_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"'
    else
        echo ""
    fi
}

# Tìm instance ID tiếp theo có sẵn
get_next_instance_id() {
    for i in $(seq 2 $MAX_INSTANCES); do
        local container_name="n8n_$i"
        local data_dir="/root/n8n_data_${i}"
        # Kiểm tra cả container và thư mục data
        if ! docker ps -a --format "{{.Names}}" 2>/dev/null | grep -qE "^${container_name}$|^n8n_data_${i}[-_]" && [ ! -d "$data_dir" ]; then
            echo "$i"
            return 0
        fi
    done
    echo ""
    return 1
}

# Tính port cho instance
get_instance_port() {
    local instance_id="$1"
    echo $((BASE_N8N_PORT + instance_id - 1))
}

# Kiểm tra tài nguyên hệ thống
check_system_resources() {
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    local used_ram=$(free -m | awk '/^Mem:/{print $3}')
    local available_ram=$((total_ram - used_ram))
    
    # Mỗi instance cần khoảng 500MB RAM
    local required_ram=500
    
    echo -e "${CYAN}📊 Tài nguyên hệ thống:${NC}"
    echo -e "   • RAM tổng: ${total_ram}MB"
    echo -e "   • RAM đã dùng: ${used_ram}MB"
    echo -e "   • RAM khả dụng: ${available_ram}MB"
    echo -e "   • RAM cần cho instance mới: ~${required_ram}MB"
    echo ""
    
    if [ $available_ram -lt $required_ram ]; then
        echo -e "${RED}⚠️  Cảnh báo: RAM khả dụng thấp! Có thể gây chậm hệ thống.${NC}"
        return 1
    fi
    
    return 0
}


# Tạo instance mới
create_new_instance() {
    echo -e "${BOLD}${GREEN}🚀 TẠO INSTANCE N8N MỚI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Kiểm tra instance mặc định
    if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
        echo -e "${RED}❌ Instance mặc định (n8n) chưa được cài đặt!${NC}"
        echo -e "${YELLOW}💡 Vui lòng cài đặt n8n đầu tiên qua menu 'Cài đặt n8n mới'${NC}"
        return 1
    fi
    
    # Tìm ID tiếp theo
    local next_id=$(get_next_instance_id)
    if [ -z "$next_id" ]; then
        echo -e "${RED}❌ Đã đạt giới hạn tối đa ($MAX_INSTANCES instances)${NC}"
        return 1
    fi
    
    local n8n_port=$(get_instance_port "$next_id")
    local db_port=$((BASE_DB_PORT + next_id - 1))
    local data_dir="/root/n8n_data_${next_id}"
    local container_name="n8n_${next_id}"
    local db_container="postgres_${next_id}"
    
    echo -e "${CYAN}📋 Thông tin instance mới:${NC}"
    echo -e "   • Instance ID: ${GREEN}$next_id${NC}"
    echo -e "   • Container N8N: ${GREEN}$container_name${NC}"
    echo -e "   • Container DB: ${GREEN}$db_container${NC}"
    echo -e "   • Port N8N: ${GREEN}$n8n_port${NC}"
    echo -e "   • Thư mục data: ${GREEN}$data_dir${NC}"
    echo ""
    
    # Kiểm tra tài nguyên
    check_system_resources
    
    # Nhập domain
    local domain=""
    while true; do
        read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập domain cho instance này: ${NC}")" domain
        if [ -z "$domain" ]; then
            echo -e "${RED}❌ Domain không được để trống${NC}"
            continue
        fi
        if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$ ]]; then
            echo -e "${RED}❌ Định dạng domain không hợp lệ${NC}"
            continue
        fi
        break
    done
    
    # Nhập email
    local email=""
    read -p "$(echo -e "${BOLD}${CYAN}📧 Nhập email (Enter = admin@$domain): ${NC}")" email
    if [ -z "$email" ]; then
        email="admin@$domain"
    fi
    
    # Xác nhận
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}Xác nhận tạo instance mới:${NC}"
    echo -e "   • Domain: ${GREEN}$domain${NC}"
    echo -e "   • Email: ${GREEN}$email${NC}"
    echo -e "   • Port: ${GREEN}$n8n_port${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    
    read -p "$(echo -e "${BOLD}${YELLOW}Tiếp tục? [Y/n]: ${NC}")" confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}❌ Đã hủy${NC}"
        return 0
    fi
    
    echo ""
    log_message "INFO" "Bắt đầu tạo instance $next_id..."
    
    # Tạo thư mục
    echo -e "${CYAN}📁 Tạo thư mục data...${NC}"
    mkdir -p "$data_dir"
    
    # Tạo credentials theo format chuẩn: n8n_inet<instance_id>_<ip_sum>
    local server_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "0.0.0.0")
    local ip_sum=0
    if [[ "$server_ip" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        ip_sum=$((${BASH_REMATCH[1]} + ${BASH_REMATCH[2]} + ${BASH_REMATCH[3]} + ${BASH_REMATCH[4]}))
    else
        ip_sum=$((RANDOM % 900 + 100))
    fi
    
    local n8n_user="n8n_inet${next_id}_${ip_sum}"
    local n8n_pass="n8n_inet${next_id}_${ip_sum}"
    local db_name="n8n_inet${next_id}"
    local db_user="n8n_inet${next_id}"
    local db_pass="n8n_inet${next_id}_${ip_sum}"
    
    # Tạo file .env
    echo -e "${CYAN}📝 Tạo file .env...${NC}"
    cat > "$data_dir/.env" <<EOF
INSTANCE_ID=${next_id}
DOMAIN=${domain}
EMAIL=${email}
N8N_USER=${n8n_user}
N8N_PASS=${n8n_pass}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_pass}
N8N_PORT=${n8n_port}
DB_PORT=${db_port}
EOF
    
    # Tạo docker-compose.yml
    echo -e "${CYAN}🐳 Tạo docker-compose.yml...${NC}"
    cat > "$data_dir/docker-compose.yml" <<EOF
services:
  ${db_container}:
    image: postgres:15
    container_name: ${db_container}
    restart: always
    environment:
      POSTGRES_USER: \${DB_USER}
      POSTGRES_PASSWORD: \${DB_PASS}
      POSTGRES_DB: \${DB_NAME}
      TZ: Asia/Ho_Chi_Minh
    volumes:
      - postgres_data_${next_id}:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER} -d \${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - n8n-network-${next_id}

  ${container_name}:
    image: n8nio/n8n:latest
    container_name: ${container_name}
    restart: always
    ports:
      - "${n8n_port}:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=\${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=\${N8N_PASS}
      - N8N_RUNNERS_ENABLED=true
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${db_container}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${DB_NAME}
      - DB_POSTGRESDB_USER=\${DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${DB_PASS}
      - N8N_HOST=\${DOMAIN}
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - WEBHOOK_URL=https://\${DOMAIN}/
      - N8N_EDITOR_BASE_URL=https://\${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - TZ=Asia/Ho_Chi_Minh
    depends_on:
      ${db_container}:
        condition: service_healthy
    volumes:
      - n8n_data_${next_id}:/home/node/.n8n
    networks:
      - n8n-network-${next_id}

networks:
  n8n-network-${next_id}:
    driver: bridge

volumes:
  postgres_data_${next_id}:
  n8n_data_${next_id}:
EOF
    
    # Khởi động containers - QUAN TRỌNG: chỉ định rõ file docker-compose
    echo -e "${CYAN}🚀 Khởi động containers...${NC}"
    local compose_file="$data_dir/docker-compose.yml"
    
    if docker-compose -f "$compose_file" up -d; then
        echo -e "${GREEN}✅ Đã gửi lệnh khởi động containers${NC}"
    else
        echo -e "${RED}❌ Lỗi khởi động containers${NC}"
        return 1
    fi
    
    # Đợi postgres healthy trước
    echo -e "${CYAN}⏳ Đợi PostgreSQL khởi động...${NC}"
    local retry=0
    local max_retry=30
    while [ $retry -lt $max_retry ]; do
        # Kiểm tra container postgres_X có chạy và healthy không
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${db_container}$"; then
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$db_container" 2>/dev/null || echo "unknown")
            if [ "$health" = "healthy" ]; then
                echo -e "${GREEN}✅ PostgreSQL (${db_container}) đã sẵn sàng${NC}"
                break
            fi
        fi
        retry=$((retry + 1))
        echo -e "${CYAN}   Đợi PostgreSQL... ($retry/$max_retry)${NC}"
        sleep 2
    done
    
    # Đợi n8n khởi động - kiểm tra bằng port
    echo -e "${CYAN}⏳ Đợi N8N khởi động trên port ${n8n_port}...${NC}"
    retry=0
    max_retry=30
    while [ $retry -lt $max_retry ]; do
        # Kiểm tra port có respond không
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${n8n_port}" 2>/dev/null | grep -qE "200|302|401"; then
            echo -e "${GREEN}✅ N8N đã sẵn sàng trên port ${n8n_port}${NC}"
            break
        fi
        retry=$((retry + 1))
        echo -e "${CYAN}   Đợi N8N... ($retry/$max_retry)${NC}"
        sleep 2
    done
    
    # Kiểm tra cuối cùng bằng port
    if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${n8n_port}" 2>/dev/null | grep -qE "200|302|401"; then
        echo -e "${RED}❌ N8N không respond trên port ${n8n_port}${NC}"
        echo -e "${YELLOW}📋 Docker-compose status:${NC}"
        docker-compose -f "$compose_file" ps
        echo -e "${YELLOW}📋 Logs:${NC}"
        docker-compose -f "$compose_file" logs --tail 30
        return 1
    fi
    
    # Cấu hình Nginx (HTTP trước để certbot có thể verify)
    echo -e "${CYAN}🌐 Cấu hình Nginx (HTTP)...${NC}"
    create_nginx_config_for_instance "$next_id" "$domain" "$n8n_port" "false"
    
    # Cài SSL bằng certbot trực tiếp (không dùng install_ssl_certificate để tránh conflict)
    echo -e "${CYAN}🔒 Cài đặt SSL...${NC}"
    if command -v certbot &>/dev/null; then
        # Cài SSL certificate
        if certbot certonly --webroot -w /var/www/html -d "$domain" --email "$email" --agree-tos --non-interactive 2>/dev/null; then
            echo -e "${GREEN}✅ Đã cài SSL thành công${NC}"
            # Cập nhật Nginx với SSL
            create_nginx_config_for_instance "$next_id" "$domain" "$n8n_port" "true"
        else
            echo -e "${YELLOW}⚠️  Không thể cài SSL tự động, site sẽ chạy HTTP${NC}"
            echo -e "${YELLOW}💡 Bạn có thể cài SSL sau qua menu 'Quản lý SSL'${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Certbot chưa được cài đặt, bỏ qua SSL${NC}"
    fi
    
    # Hoàn tất
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ TẠO INSTANCE MỚI THÀNH CÔNG!                           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 Thông tin đăng nhập:${NC}"
    echo -e "   • URL: ${GREEN}https://$domain${NC}"
    echo -e "   • User: ${GREEN}$n8n_user${NC}"
    echo -e "   • Pass: ${GREEN}$n8n_pass${NC}"
    echo ""
    
    log_message "SUCCESS" "Đã tạo instance $next_id thành công"
    return 0
}


# Tạo Nginx config cho instance
create_nginx_config_for_instance() {
    local instance_id="$1"
    local domain="$2"
    local port="$3"
    local with_ssl="${4:-false}"
    
    local config_name="n8n"
    if [ "$instance_id" != "1" ]; then
        config_name="n8n_${instance_id}"
    fi
    
    local config_file="/etc/nginx/sites-available/$config_name"
    
    if [ "$with_ssl" = "true" ] && [ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]; then
        # Config với SSL
        cat > "$config_file" <<EOF
server {
    listen 443 ssl http2;
    server_name ${domain};
    
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://localhost:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}

server {
    listen 80;
    server_name ${domain};
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
    else
        # Config HTTP only
        cat > "$config_file" <<EOF
server {
    listen 80;
    server_name ${domain};
    
    client_max_body_size 50M;
    
    location /.well-known/acme-challenge/ { root /var/www/html; }
    
    location / {
        proxy_pass http://localhost:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
EOF
    fi
    
    # Enable site
    ln -sf "$config_file" "/etc/nginx/sites-enabled/$config_name" 2>/dev/null
    
    # Reload nginx
    nginx -t && systemctl reload nginx
}

# Xóa instance
delete_instance() {
    echo -e "${BOLD}${RED}🗑️  XÓA INSTANCE N8N${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Liệt kê instances
    list_all_instances
    
    # Chọn instance để xóa
    read -p "$(echo -e "${BOLD}${RED}Nhập ID instance cần xóa (2-$MAX_INSTANCES, không thể xóa instance 1): ${NC}")" instance_id
    
    if [ -z "$instance_id" ] || [ "$instance_id" = "1" ]; then
        echo -e "${RED}❌ Không thể xóa instance mặc định (1). Dùng menu 'Gỡ cài đặt' để xóa hoàn toàn.${NC}"
        return 1
    fi
    
    if ! [[ "$instance_id" =~ ^[0-9]+$ ]] || [ "$instance_id" -lt 2 ] || [ "$instance_id" -gt $MAX_INSTANCES ]; then
        echo -e "${RED}❌ ID không hợp lệ${NC}"
        return 1
    fi
    
    local data_dir="/root/n8n_data_${instance_id}"
    
    # Tìm container name thực tế
    local container_name=$(find_instance_containers "$instance_id" "n8n")
    local db_container=$(find_instance_containers "$instance_id" "postgres")
    
    # Kiểm tra instance tồn tại (container hoặc thư mục data)
    local container_exists=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$" && echo "yes" || echo "no")
    
    if [ "$container_exists" = "no" ] && [ ! -d "$data_dir" ]; then
        echo -e "${RED}❌ Instance $instance_id không tồn tại${NC}"
        return 1
    fi
    
    local domain=$(get_instance_domain "$instance_id")
    
    echo ""
    echo -e "${RED}⚠️  CẢNH BÁO: Sẽ xóa hoàn toàn instance $instance_id${NC}"
    echo -e "${RED}   • Container: $container_name, $db_container${NC}"
    echo -e "${RED}   • Data: $data_dir${NC}"
    echo -e "${RED}   • Domain: ${domain:-N/A}${NC}"
    echo ""
    
    read -p "$(echo -e "${BOLD}${RED}Gõ 'XOA' để xác nhận: ${NC}")" confirm
    if [ "$confirm" != "XOA" ]; then
        echo -e "${YELLOW}❌ Đã hủy${NC}"
        return 0
    fi
    
    log_message "INFO" "Bắt đầu xóa instance $instance_id..."
    
    # Dừng và xóa containers
    echo -e "${CYAN}⏹️  Dừng containers...${NC}"
    if [ -f "$data_dir/docker-compose.yml" ]; then
        docker-compose -f "$data_dir/docker-compose.yml" down -v 2>/dev/null
    fi
    docker stop "$container_name" "$db_container" 2>/dev/null
    docker rm "$container_name" "$db_container" 2>/dev/null
    
    # Xóa volumes (tìm tất cả volumes liên quan)
    echo -e "${CYAN}💾 Xóa volumes...${NC}"
    # Tìm và xóa tất cả volumes có chứa instance_id
    local volumes=$(docker volume ls -q 2>/dev/null | grep -E "n8n_data_${instance_id}|postgres_data_${instance_id}|n8n_data_${instance_id}_" || true)
    if [ -n "$volumes" ]; then
        echo "$volumes" | xargs docker volume rm 2>/dev/null || true
    fi
    
    # Xóa thư mục data
    echo -e "${CYAN}📁 Xóa thư mục data...${NC}"
    rm -rf "$data_dir"
    
    # Xóa Nginx config
    echo -e "${CYAN}🌐 Xóa Nginx config...${NC}"
    rm -f "/etc/nginx/sites-available/n8n_${instance_id}"
    rm -f "/etc/nginx/sites-enabled/n8n_${instance_id}"
    nginx -t && systemctl reload nginx 2>/dev/null
    
    # Xóa SSL (nếu có)
    if [ -n "$domain" ]; then
        echo -e "${CYAN}🔒 Xóa SSL certificate...${NC}"
        certbot delete --cert-name "$domain" --non-interactive 2>/dev/null || true
    fi
    
    echo ""
    echo -e "${GREEN}✅ Đã xóa instance $instance_id thành công${NC}"
    log_message "SUCCESS" "Đã xóa instance $instance_id"
    return 0
}

# Tìm container name thực tế cho instance
find_instance_containers() {
    local instance_id="$1"
    local container_type="$2"  # "n8n" hoặc "postgres"
    
    if [ "$instance_id" = "1" ]; then
        if [ "$container_type" = "n8n" ]; then
            echo "n8n"
        else
            echo "postgres"
        fi
        return 0
    fi
    
    local expected_name="${container_type}_${instance_id}"
    if [ "$container_type" = "n8n" ]; then
        expected_name="n8n_${instance_id}"
    fi
    
    # Tìm container với các pattern có thể
    local found=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${expected_name}$|n8n_data_${instance_id}[-_]${expected_name}" | head -1)
    
    if [ -n "$found" ]; then
        echo "$found"
    else
        echo "$expected_name"
    fi
}

# Quản lý instance (start/stop/restart)
manage_instance() {
    echo -e "${BOLD}${CYAN}⚙️  QUẢN LÝ INSTANCE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    list_all_instances
    
    read -p "$(echo -e "${BOLD}${CYAN}Nhập ID instance cần quản lý (1-$MAX_INSTANCES): ${NC}")" instance_id
    
    if [ -z "$instance_id" ] || ! [[ "$instance_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ ID không hợp lệ${NC}"
        return 1
    fi
    
    local data_dir="/root/n8n_data"
    if [ "$instance_id" != "1" ]; then
        data_dir="/root/n8n_data_${instance_id}"
    fi
    
    # Tìm container name thực tế
    local container_name=$(find_instance_containers "$instance_id" "n8n")
    local db_container=$(find_instance_containers "$instance_id" "postgres")
    
    # Kiểm tra instance tồn tại (container hoặc thư mục data)
    local container_exists=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$" && echo "yes" || echo "no")
    
    if [ "$container_exists" = "no" ] && [ ! -d "$data_dir" ]; then
        echo -e "${RED}❌ Instance $instance_id không tồn tại${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}Chọn thao tác cho instance $instance_id:${NC}"
    echo -e "${CYAN}1.${NC} Khởi động (start)"
    echo -e "${CYAN}2.${NC} Dừng (stop)"
    echo -e "${CYAN}3.${NC} Khởi động lại (restart)"
    echo -e "${CYAN}4.${NC} Xem logs"
    echo -e "${RED}0.${NC} Quay lại"
    echo ""
    
    read -p "$(echo -e "${BOLD}${CYAN}Chọn [0-4]: ${NC}")" action
    
    case $action in
        1)
            echo -e "${CYAN}▶️  Khởi động instance $instance_id...${NC}"
            # Thử start container trước
            if docker start "$db_container" 2>/dev/null; then
                sleep 3
                docker start "$container_name" 2>/dev/null
                echo -e "${GREEN}✅ Đã khởi động${NC}"
            elif [ -f "$data_dir/docker-compose.yml" ]; then
                # Nếu container không tồn tại, dùng docker-compose
                echo -e "${CYAN}   Containers chưa tồn tại, đang tạo từ docker-compose...${NC}"
                docker-compose -f "$data_dir/docker-compose.yml" up -d
                echo -e "${GREEN}✅ Đã khởi động từ docker-compose${NC}"
            else
                echo -e "${RED}❌ Không thể khởi động - không tìm thấy container hoặc docker-compose.yml${NC}"
            fi
            ;;
        2)
            echo -e "${CYAN}⏹️  Dừng instance $instance_id...${NC}"
            docker stop "$container_name" "$db_container" 2>/dev/null
            echo -e "${GREEN}✅ Đã dừng${NC}"
            ;;
        3)
            echo -e "${CYAN}🔄 Khởi động lại instance $instance_id...${NC}"
            if [ -f "$data_dir/docker-compose.yml" ]; then
                docker-compose -f "$data_dir/docker-compose.yml" restart
            else
                docker restart "$db_container" 2>/dev/null
                sleep 3
                docker restart "$container_name" 2>/dev/null
            fi
            echo -e "${GREEN}✅ Đã khởi động lại${NC}"
            ;;
        4)
            echo -e "${CYAN}📋 Logs của $container_name:${NC}"
            docker logs --tail 50 "$container_name" 2>&1
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
            ;;
    esac
}

# Menu chính Multi-Instance
handle_multi_instance_menu() {
    while true; do
        clear
        print_banner
        
        echo -e "${BOLD}${CYAN}                            MENU MULTI-INSTANCE N8N${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}QUẢN LÝ INSTANCE${NC}                          ${BOLD}${CYAN}THAO TÁC NÂNG CAO${NC}"
        echo -e "  ${GREEN}───────────────────────${NC}                   ${CYAN}──────────────────────────${NC}"
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Liệt kê tất cả instances  ${NC}       ${BOLD}${CYAN}3.${NC} ${WHITE}Quản lý instance${NC}"
        echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Tạo instance mới          ${NC}       ${BOLD}${RED}4.${NC} ${WHITE}Xóa instance${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại menu chính${NC}"
        echo ""
        echo -e "${BOLD}${YELLOW}Mẹo:${NC} ${WHITE}Mỗi instance chạy độc lập với domain và port riêng${NC}"
        echo ""
        
        read -p "$(echo -e "${BOLD}${CYAN}Chọn tùy chọn [0-4]: ${NC}")" choice
        
        case $choice in
            1)
                echo ""
                list_all_instances
                ;;
            2)
                echo ""
                create_new_instance
                ;;
            3)
                echo ""
                manage_instance
                ;;
            4)
                echo ""
                delete_instance
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
                sleep 1
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo ""
            read -p "$(echo -e "${BOLD}${YELLOW}Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}
