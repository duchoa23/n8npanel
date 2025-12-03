#!/usr/bin/env bash

# Module Cập nhật
# Chứa các hàm liên quan đến cập nhật N8N, Panel, và quản lý network

version_greater_than() {
    local version1="$1"
    local version2="$2"
    
    version1=$(echo "$version1" | sed 's/^v//; s/[^0-9.]//g')
    version2=$(echo "$version2" | sed 's/^v//; s/[^0-9.]//g')
    
    local v1_major=$(echo "$version1" | cut -d'.' -f1)
    local v1_minor=$(echo "$version1" | cut -d'.' -f2 2>/dev/null || echo "0")
    local v2_major=$(echo "$version2" | cut -d'.' -f1)
    local v2_minor=$(echo "$version2" | cut -d'.' -f2 2>/dev/null || echo "0")
    
    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    
    if [ "$v1_major" -gt "$v2_major" ] 2>/dev/null; then
        return 0
    elif [ "$v1_major" -eq "$v2_major" ] 2>/dev/null && [ "$v1_minor" -gt "$v2_minor" ] 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

download_remote_manifest() {
    local manifest_url="${MANIFEST_URL:-https://drive.inet.vn/uploads/v3/manifest.json}"
    local manifest_file="/tmp/n8n_manifest_remote_$(date +%s).json"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        retry_count=$((retry_count + 1))
        
        if curl -s --connect-timeout 15 --retry 2 "$manifest_url" -o "$manifest_file" 2>/dev/null; then
            # Kiểm tra file có hợp lệ không
            if [ -s "$manifest_file" ]; then
                # Kiểm tra có phải JSON hợp lệ không
                if command -v jq >/dev/null 2>&1; then
                    if jq empty "$manifest_file" 2>/dev/null; then
                        echo "$manifest_file"
                        return 0
                    else
                        log_message "WARN" "Manifest không phải JSON hợp lệ (lần thử $retry_count/$max_retries)"
                    fi
                else
                    # Không có jq, kiểm tra cơ bản
                    if head -c 1 "$manifest_file" | grep -q '{'; then
                        echo "$manifest_file"
                        return 0
                    fi
                fi
            fi
        fi
        
        if [ $retry_count -lt $max_retries ]; then
            log_message "WARN" "Tải manifest thất bại, thử lại sau 2 giây... ($retry_count/$max_retries)"
            sleep 2
        fi
    done
    
    log_message "ERROR" "Không thể tải manifest sau $max_retries lần thử"
    rm -f "$manifest_file" 2>/dev/null
    return 1
}

get_local_manifest() {
    local local_manifest="$INSTALL_DIR/manifest.json"
    if [ -f "$local_manifest" ]; then
        echo "$local_manifest"
        return 0
    fi
    return 1
}

check_panel_version() {
    local manifest_file=$(download_remote_manifest)
    
    if [ $? -ne 0 ] || [ -z "$manifest_file" ]; then
        return 1
    fi
    
    local remote_version=$(jq -r '.version' "$manifest_file" 2>/dev/null)
    rm -f "$manifest_file"
    
    if [ -z "$remote_version" ] || [ "$remote_version" = "null" ]; then
        return 1
    fi
    
    echo "$remote_version"
}

download_missing_files() {
    local files=("$@")
    local manifest_file=$(download_remote_manifest)
    
    if [ $? -ne 0 ] || [ -z "$manifest_file" ]; then
        echo -e "${RED}❌ Không thể tải manifest từ server${NC}"
        return 1
    fi
    
    local success_count=0
    local fail_count=0
    
    for file in "${files[@]}"; do
        # Lấy URL từ manifest (key là đường dẫn đầy đủ)
        local url=$(jq -r ".files.\"$file\".url" "$manifest_file" 2>/dev/null)
        
        if [ -z "$url" ] || [ "$url" = "null" ]; then
            echo -e "${YELLOW}⚠️  Không tìm thấy URL cho: $file${NC}"
            ((fail_count++))
            continue
        fi
        
        # Tạo thư mục nếu cần
        local dir=$(dirname "$file")
        if [ "$dir" != "." ]; then
            mkdir -p "$INSTALL_DIR/$dir"
        fi
        
        # Tải file
        echo -e "${CYAN}📥 Đang tải: $file${NC}"
        if curl -s --connect-timeout 30 "$url" -o "$INSTALL_DIR/$file" 2>/dev/null; then
            chmod +x "$INSTALL_DIR/$file" 2>/dev/null
            echo -e "${GREEN}✅ Đã tải: $file${NC}"
            ((success_count++))
        else
            echo -e "${RED}❌ Lỗi tải: $file${NC}"
            ((fail_count++))
        fi
    done
    
    rm -f "$manifest_file"
    
    echo ""
    echo -e "${CYAN}📊 Kết quả: ${GREEN}$success_count thành công${NC}, ${RED}$fail_count thất bại${NC}"
    
    return $fail_count
}

update_panel() {
    echo -e "${BOLD}${CYAN}🔄 ĐANG KIỂM TRA CẬP NHẬT PANEL...${NC}\n"
    
    # Đọc version từ manifest local
    local local_manifest=$(get_local_manifest)
    local current_version="$SCRIPT_VERSION"
    
    if [ -n "$local_manifest" ]; then
        current_version=$(jq -r '.version' "$local_manifest" 2>/dev/null || echo "$SCRIPT_VERSION")
    fi
    
    echo -e "${CYAN}📋 Phiên bản hiện tại: ${BOLD}v${current_version}${NC}"
    echo -e "${CYAN}🏗️  Kiến trúc: ${BOLD}${SCRIPT_ARCHITECTURE}${NC}"
    
    # Kiểm tra jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Cần cài đặt 'jq' để cập nhật tự động${NC}"
        echo -e "${CYAN}💡 Đang cài đặt jq...${NC}"
        if apt update && apt install -y jq 2>/dev/null; then
            echo -e "${GREEN}✅ Đã cài đặt jq${NC}"
        else
            echo -e "${RED}❌ Không thể cài đặt jq tự động${NC}"
            echo -e "${YELLOW}💡 Chạy thủ công: apt update && apt install -y jq${NC}"
            return 1
        fi
    fi
    
    echo -e "${CYAN}🌐 Đang kiểm tra phiên bản mới từ server...${NC}"
    
    local remote_manifest=$(download_remote_manifest)
    
    if [ $? -ne 0 ] || [ -z "$remote_manifest" ]; then
        echo -e "${RED}❌ Không thể tải thông tin phiên bản từ server${NC}"
        echo -e "${YELLOW}💡 Vui lòng kiểm tra kết nối internet${NC}"
        return 1
    fi
    
    local remote_version=$(jq -r '.version' "$remote_manifest")
    local release_date=$(jq -r '.release_date' "$remote_manifest")
    
    echo -e "${CYAN}📋 Phiên bản mới nhất: ${BOLD}v${remote_version}${NC}"
    echo -e "${CYAN}📅 Ngày phát hành: ${BOLD}${release_date}${NC}"
    
    if version_greater_than "$remote_version" "$current_version"; then
        echo -e "\n${GREEN}🎉 Có phiên bản mới available!${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}   Phiên bản hiện tại: ${BOLD}v${current_version}${NC}"
        echo -e "${GREEN}   Phiên bản mới:     ${BOLD}v${remote_version}${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════${NC}"
        
        # Hiển thị changelog cho phiên bản mới
        echo -e "\n${BOLD}${PURPLE}📝 THAY ĐỔI MỚI (v${remote_version}):${NC}"
        local changelog=$(jq -r ".changelog.\"$remote_version\"[]" "$remote_manifest" 2>/dev/null)
        if [ -n "$changelog" ]; then
            while IFS= read -r line; do
                echo -e "${GREEN}  •${NC} $line"
            done <<< "$changelog"
        else
            echo -e "${YELLOW}  Không có thông tin changelog${NC}"
        fi
        
        echo ""
        read -p "$(echo -e "${YELLOW}Bạn có muốn cập nhật panel không? [Y/n]: ${NC}")" update_confirm
        
        if [[ "$update_confirm" =~ ^[Yy]$ ]] || [ -z "$update_confirm" ]; then
            perform_smart_update "$remote_manifest" "$local_manifest"
        else
            echo -e "${YELLOW}ℹ️  Bỏ qua cập nhật panel${NC}"
            rm -f "$remote_manifest"
        fi
    else
        echo -e "\n${GREEN}✅ Panel đã là phiên bản mới nhất!${NC}"
        rm -f "$remote_manifest"
    fi
    echo ""
}

perform_smart_update() {
    local remote_manifest="$1"
    local local_manifest="$2"
    local backup_dir="/tmp/n8n_panel_backup_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${BOLD}${CYAN}🚀 BẮT ĐẦU QUÁ TRÌNH CẬP NHẬT...${NC}\n"
    
    # Bước 1: Backup
    echo -e "${CYAN}📦 Bước 1/4: Backup panel hiện tại...${NC}"
    mkdir -p "$backup_dir"
    
    if tar -czf "$backup_dir/panel_backup.tar.gz" -C "$INSTALL_DIR" . 2>/dev/null; then
        echo -e "${GREEN}✅ Đã backup tại: $backup_dir${NC}"
    else
        echo -e "${YELLOW}⚠️  Không thể tạo backup, tiếp tục cập nhật...${NC}"
    fi
    
    # Bước 2: Kiểm tra và tạo cấu trúc thư mục
    echo -e "\n${CYAN}📁 Bước 2/4: Kiểm tra cấu trúc thư mục...${NC}"
    
    # Lấy danh sách thư mục duy nhất từ files
    local directories=$(jq -r '.files[].path' "$remote_manifest" | sort -u)
    
    for dir in $directories; do
        if [ "$dir" != "root" ] && [ ! -d "$INSTALL_DIR/$dir" ]; then
            mkdir -p "$INSTALL_DIR/$dir"
            echo -e "${GREEN}✅ Tạo thư mục: $dir${NC}"
        fi
    done
    
    # Bước 3: So sánh và tải file cần cập nhật
    echo -e "\n${CYAN}📥 Bước 3/4: Phân tích và tải file cần cập nhật...${NC}"
    
    local total_files=0
    local updated_files=0
    local skipped_files=0
    local failed_files=0
    local new_files=0
    
    # Lấy danh sách tất cả file từ remote manifest
    local all_files=$(jq -r '.files | keys[]' "$remote_manifest")
    
    for file_key in $all_files; do
        ((total_files++))
        
        local url=$(jq -r ".files.\"$file_key\".url" "$remote_manifest")
        local required=$(jq -r ".files.\"$file_key\".required" "$remote_manifest")
        local remote_version=$(jq -r ".files.\"$file_key\".version" "$remote_manifest")
        local file_path=$(jq -r ".files.\"$file_key\".path" "$remote_manifest")
        local install_path=$(jq -r ".files.\"$file_key\".install_path" "$remote_manifest")
        
        # Xác định đường dẫn đích
        local dest_path="$INSTALL_DIR/$file_key"
        
        # Nếu có install_path đặc biệt (như hook.py), dùng đường dẫn đó
        if [ -n "$install_path" ] && [ "$install_path" != "null" ]; then
            dest_path="$install_path"
            # Tạo thư mục cha nếu cần
            local parent_dir=$(dirname "$dest_path")
            mkdir -p "$parent_dir" 2>/dev/null
        fi
        
        # Kiểm tra xem file có cần cập nhật không
        local needs_update=false
        local update_reason=""
        
        if [ ! -f "$dest_path" ]; then
            # File chưa tồn tại
            needs_update=true
            update_reason="file mới"
            ((new_files++))
        elif [ -n "$local_manifest" ]; then
            # So sánh version với local manifest
            local local_version=$(jq -r ".files.\"$file_key\".version" "$local_manifest" 2>/dev/null)
            
            if [ -z "$local_version" ] || [ "$local_version" = "null" ]; then
                # File không có trong local manifest
                needs_update=true
                update_reason="chưa có version"
            elif [ "$remote_version" != "$local_version" ]; then
                # Version khác nhau
                needs_update=true
                update_reason="version mới ($local_version → $remote_version)"
            else
                # Version giống nhau, nhưng kiểm tra thêm cho hook.py
                if [ "$file_key" = "hook.py" ] && [ -f "$dest_path" ]; then
                    # Đọc version từ file hook.py thực tế
                    local hook_file_version=$(grep "^HOOK_VERSION = " "$dest_path" 2>/dev/null | cut -d'"' -f2)
                    if [ -n "$hook_file_version" ] && [ "$hook_file_version" != "$remote_version" ]; then
                        needs_update=true
                        update_reason="version trong file khác ($hook_file_version → $remote_version)"
                    else
                        needs_update=false
                        ((skipped_files++))
                    fi
                else
                    # Version giống nhau, skip
                    needs_update=false
                    ((skipped_files++))
                fi
            fi
        else
            # Không có local manifest, cập nhật tất cả
            needs_update=true
            update_reason="không có manifest local"
        fi
        
        if [ "$needs_update" = true ]; then
            # Hiển thị đích đến nếu là đường dẫn đặc biệt
            if [ -n "$install_path" ] && [ "$install_path" != "null" ]; then
                echo -e "${CYAN}  📥 Đang tải: $file_key → ${PURPLE}$install_path${NC} ${YELLOW}($update_reason)${NC}"
            else
                echo -e "${CYAN}  📥 Đang tải: $file_key ${YELLOW}($update_reason)${NC}"
            fi
            
            # Tải file
            if curl -s --connect-timeout 30 "$url" -o "$dest_path" 2>/dev/null; then
                chmod +x "$dest_path" 2>/dev/null
                ((updated_files++))
                echo -e "${GREEN}     ✅ Thành công${NC}"
            else
                echo -e "${RED}     ❌ Lỗi tải${NC}"
                ((failed_files++))
                
                if [ "$required" = "true" ]; then
                    echo -e "${RED}⚠️  File bắt buộc không tải được, đang rollback...${NC}"
                    
                    # Rollback từ backup
                    if [ -f "$backup_dir/panel_backup.tar.gz" ]; then
                        echo -e "${YELLOW}🔄 Đang khôi phục từ backup...${NC}"
                        if tar -xzf "$backup_dir/panel_backup.tar.gz" -C "$INSTALL_DIR" 2>/dev/null; then
                            echo -e "${GREEN}✅ Đã rollback thành công${NC}"
                        else
                            echo -e "${RED}❌ Rollback thất bại! Vui lòng khôi phục thủ công từ: $backup_dir${NC}"
                        fi
                    fi
                    
                    rm -f "$remote_manifest"
                    return 1
                fi
            fi
        fi
    done
    
    # Bước 4: Cấp quyền và hoàn tất
    echo -e "\n${CYAN}🔧 Bước 4/4: Hoàn tất cập nhật...${NC}"
    
    # Cấp quyền thực thi cho tất cả file .sh
    find "$INSTALL_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    echo -e "${GREEN}✅ Đã cấp quyền thực thi${NC}"
    
    # Cập nhật manifest.json local bằng manifest từ server
    local new_version=$(jq -r '.version' "$remote_manifest")
    cp "$remote_manifest" "$INSTALL_DIR/manifest.json"
    echo -e "${GREEN}✅ Đã cập nhật manifest.json lên v$new_version${NC}"
    
    # Lưu thông tin cập nhật
    cat > "$INSTALL_DIR/.last_update" <<EOF
VERSION=$new_version
UPDATE_DATE=$(date)
UPDATE_METHOD=smart_update
BACKUP_LOCATION=$backup_dir
EOF
    
    rm -f "$remote_manifest"
    
    # Hiển thị kết quả
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                           ✅ CẬP NHẬT HOÀN TẤT! ✅                                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CYAN}📊 Thống kê cập nhật:${NC}"
    echo -e "${GREEN}  • Tổng số file: $total_files${NC}"
    echo -e "${GREEN}  • File mới: $new_files${NC}"
    echo -e "${GREEN}  • Đã cập nhật: $updated_files${NC}"
    echo -e "${YELLOW}  • Bỏ qua (không đổi): $skipped_files${NC}"
    if [ $failed_files -gt 0 ]; then
        echo -e "${RED}  • Thất bại: $failed_files${NC}"
    fi
    echo -e "${CYAN}  • Phiên bản mới: v$new_version${NC}"
    echo -e "${CYAN}  • Backup tại: $backup_dir${NC}"
    
    echo -e "\n${YELLOW}🔄 Khởi động lại panel để sử dụng phiên bản mới...${NC}"
    sleep 2
    
    exec "$INSTALL_DIR/n8n.sh"
}

update_n8n() {
    echo -e "${BOLD}${CYAN}🔄 ĐANG CẬP NHẬT N8N...${NC}\n"
    
    if ! docker ps | grep -q "n8n"; then
        echo -e "${RED}❌ N8N container không đang chạy${NC}"
        echo -e "${YELLOW}💡 Vui lòng khởi động N8N trước khi cập nhật${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Kiểm tra phiên bản hiện tại...${NC}"
    local current_version=$(docker exec n8n n8n --version 2>/dev/null || echo "Không xác định")
    echo -e "${CYAN}   Phiên bản hiện tại: ${current_version}${NC}"
    
    echo -e "\n${YELLOW}⚠️  CẢNH BÁO: Quá trình cập nhật sẽ khởi động lại N8N${NC}"
    echo -e "${YELLOW}   Điều này có thể gián đoạn các workflow đang chạy${NC}"
    echo -e "\n${CYAN}Bạn có muốn tiếp tục? (y/n): ${NC}"
    read -p "" update_confirm
    
    if [[ ! "$update_confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}ℹ️  Đã hủy cập nhật N8N${NC}"
        return 0
    fi
    
    echo -e "\n${CYAN}💾 Tạo backup trước khi cập nhật...${NC}"
    if type create_manual_backup &>/dev/null; then
        create_manual_backup
    else
        echo -e "${YELLOW}⚠️  Module backup chưa được load, bỏ qua backup${NC}"
    fi
    
    cd "$N8N_DATA_DIR" || {
        echo -e "${RED}❌ Không thể chuyển đến thư mục $N8N_DATA_DIR${NC}"
        return 1
    }
    
    echo -e "\n${CYAN}🔄 Đang cập nhật N8N...${NC}"
    echo -e "${CYAN}   📥 Đang tải image N8N mới nhất...${NC}"
    
    if docker-compose pull n8n; then
        echo -e "${GREEN}   ✅ Đã tải image N8N thành công${NC}"
    else
        echo -e "${RED}   ❌ Không thể tải image N8N mới${NC}"
        return 1
    fi
    
    echo -e "${CYAN}   🔄 Đang khởi động lại N8N với phiên bản mới...${NC}"
    
    if docker-compose up -d n8n; then
        echo -e "${GREEN}   ✅ Đã khởi động lại N8N thành công${NC}"
    else
        echo -e "${RED}   ❌ Lỗi khi khởi động lại N8N${NC}"
        return 1
    fi
    
    echo -e "\n${CYAN}⏳ Đang đợi N8N khởi động hoàn tất...${NC}"
    local retry_count=0
    local max_retries=12
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|302\|404"; then
            break
        fi
        retry_count=$((retry_count + 1))
        echo -e "${CYAN}   ⏳ Đang đợi... ($retry_count/$max_retries)${NC}"
        sleep 5
    done
    
    if [ $retry_count -ge $max_retries ]; then
        echo -e "${YELLOW}⚠️  N8N chưa phản hồi sau 60 giây, nhưng có thể vẫn đang khởi động${NC}"
    else
        echo -e "${GREEN}✅ N8N đã khởi động thành công${NC}"
    fi
    
    echo -e "\n${CYAN}📋 Kiểm tra phiên bản sau cập nhật...${NC}"
    sleep 3
    local new_version=$(docker exec n8n n8n --version 2>/dev/null || echo "Không xác định")
    echo -e "${GREEN}   Phiên bản mới: ${new_version}${NC}"
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                              ✅ CẬP NHẬT N8N HOÀN TẤT! ✅                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CYAN}📋 Tóm tắt cập nhật:${NC}"
    echo -e "${CYAN}   • Phiên bản cũ: ${current_version}${NC}"
    echo -e "${GREEN}   • Phiên bản mới: ${new_version}${NC}"
    
    log_message "SUCCESS" "Cập nhật N8N thành công từ $current_version lên $new_version"
}

manage_network_stack() {
    while true; do
        clear
        print_banner
        
        echo -e "${BOLD}${CYAN}🌐 QUẢN LÝ CẤU HÌNH MẠNG${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        
        local ipv4=$(get_server_ipv4)
        local ipv6=$(get_server_ipv6)
        local nginx_ipv4=$(grep -q "listen 80;" /etc/nginx/sites-available/n8n 2>/dev/null && echo "✅" || echo "❌")
        local nginx_ipv6=$(grep -q "listen \[::\]:" /etc/nginx/sites-available/n8n 2>/dev/null && echo "✅" || echo "❌")
        local docker_ipv6=$(grep -q '"ipv6".*true' /etc/docker/daemon.json 2>/dev/null && echo "✅" || echo "❌")
        
        echo -e "${YELLOW}📊 Trạng thái hiện tại:${NC}"
        echo -e "${CYAN}   • Server IPv4: ${ipv4:-"❌ Không có"}${NC}"
        echo -e "${CYAN}   • Server IPv6: ${ipv6:-"❌ Không có"}${NC}"
        echo -e "${CYAN}   • Nginx IPv4: $nginx_ipv4 | IPv6: $nginx_ipv6${NC}"
        echo -e "${CYAN}   • Docker IPv6: $docker_ipv6${NC}"
        echo ""
        
        echo -e "${BOLD}${GREEN}CHỌN CHẾ ĐỘ MẠNG:${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Chỉ chạy IPv4${NC}"
        echo -e "     ${CYAN}└─ Tắt IPv6, chỉ sử dụng IPv4${NC}"
        echo ""
        echo -e "  ${BOLD}${PURPLE}2.${NC} ${WHITE}Chỉ chạy IPv6${NC}"
        echo -e "     ${CYAN}└─ Tắt IPv4, chỉ sử dụng IPv6 (yêu cầu server có IPv6)${NC}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}3.${NC} ${WHITE}Dual-stack (IPv4 + IPv6)${NC}"
        echo -e "     ${CYAN}└─ Chạy song song cả IPv4 và IPv6${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại${NC}"
        echo ""
        
        read -p "$(echo -e "${BOLD}${CYAN}Chọn chế độ [0-3]: ${NC}")" network_choice
        
        case $network_choice in
            1) 
                echo -e "\n${BOLD}${GREEN}🌐 CẤU HÌNH CHẾ ĐỘ IPv4 ONLY...${NC}\n"
                echo -e "${YELLOW}Tính năng đang được phát triển...${NC}"
                ;;
            2) 
                echo -e "\n${BOLD}${PURPLE}🌐 CẤU HÌNH CHẾ ĐỘ IPv6 ONLY...${NC}\n"
                echo -e "${YELLOW}Tính năng đang được phát triển...${NC}"
                ;;
            3) 
                echo -e "\n${BOLD}${YELLOW}🌐 CẤU HÌNH CHẾ ĐỘ DUAL-STACK...${NC}\n"
                echo -e "${YELLOW}Tính năng đang được phát triển...${NC}"
                ;;
            0) 
                break 
                ;;
            *) 
                echo -e "\n${BOLD}${RED}❌ Tùy chọn không hợp lệ!${NC}"
                sleep 2
                continue 
                ;;
        esac
        
        if [ "$network_choice" != "0" ] && [ "$network_choice" -ge 1 ] && [ "$network_choice" -le 3 ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
            read -p "$(echo -e "${BOLD}${YELLOW}⏸️  Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}

handle_update_menu() {
    while true; do
        clear
        print_banner
        
        echo -e "${BOLD}${CYAN}MENU CẬP NHẬT${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}CẬP NHẬT ỨNG DỤNG${NC}                   ${BOLD}${PURPLE}CẤU HÌNH MẠNG${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Cập nhật N8N (chọn instance)${NC}       ${BOLD}${PURPLE}3.${NC} ${WHITE}Quản lý cấu hình mạng${NC}"
        echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Cập nhật Panel${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại menu chính${NC}"
        
        read -p "$(echo -e "${BOLD}${CYAN}Chọn tùy chọn [0-3]: ${NC}")" update_choice
        
        case $update_choice in
            1)
                echo -e "\n${BOLD}${GREEN}🔄 CẬP NHẬT N8N...${NC}\n"
                update_n8n_with_instance_select
                ;;
            2)
                echo -e "\n${BOLD}${CYAN}🔄 CẬP NHẬT PANEL...${NC}\n"
                update_panel
                ;;
            3)
                echo -e "\n${BOLD}${PURPLE}🌐 QUẢN LÝ CẤU HÌNH MẠNG...${NC}\n"
                manage_network_stack
                ;;
            0)
                break
                ;;
            *)
                echo -e "\n${BOLD}${RED}❌ Tùy chọn không hợp lệ! Vui lòng chọn từ 0-3.${NC}"
                sleep 2
                ;;
        esac
        
        if [ "$update_choice" != "0" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
            read -p "$(echo -e "${BOLD}${YELLOW}⏸️  Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}

# Wrapper function để update N8N với chọn instance
update_n8n_with_instance_select() {
    # Chọn instance nếu có nhiều instance
    if type select_instance_for_operation &>/dev/null; then
        if ! select_instance_for_operation "Chọn instance N8N để cập nhật"; then
            return 0
        fi
        # Cập nhật các biến global cho instance được chọn
        N8N_DATA_DIR="$SELECTED_DATA_DIR"
        COMPOSE_FILE="$SELECTED_COMPOSE_FILE"
    fi
    
    local container_name="${SELECTED_CONTAINER:-n8n}"
    local data_dir="${SELECTED_DATA_DIR:-/root/n8n_data}"
    local compose_file="${SELECTED_COMPOSE_FILE:-$data_dir/docker-compose.yml}"
    local instance_id="${SELECTED_INSTANCE:-1}"
    local domain="${SELECTED_DOMAIN:-$(get_current_domain 2>/dev/null)}"
    
    echo -e "${BOLD}${CYAN}🔄 ĐANG CẬP NHẬT N8N...${NC}\n"
    echo -e "${YELLOW}📌 Instance: ${instance_id} | Domain: ${domain} | Container: ${container_name}${NC}"
    echo ""
    
    if ! docker ps | grep -q "$container_name"; then
        echo -e "${RED}❌ Container $container_name không đang chạy${NC}"
        echo -e "${YELLOW}💡 Vui lòng khởi động N8N trước khi cập nhật${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Kiểm tra phiên bản hiện tại...${NC}"
    local current_version=$(docker exec "$container_name" n8n --version 2>/dev/null || echo "Không xác định")
    echo -e "${CYAN}   Phiên bản hiện tại: ${current_version}${NC}"
    
    echo -e "\n${YELLOW}⚠️  CẢNH BÁO: Quá trình cập nhật sẽ khởi động lại N8N${NC}"
    echo -e "${YELLOW}   Điều này có thể gián đoạn các workflow đang chạy${NC}"
    echo -e "\n${CYAN}Bạn có muốn tiếp tục? (y/n): ${NC}"
    read -p "" update_confirm
    
    if [[ ! "$update_confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}ℹ️  Đã hủy cập nhật N8N${NC}"
        return 0
    fi
    
    echo -e "\n${CYAN}💾 Tạo backup trước khi cập nhật...${NC}"
    if type create_manual_backup &>/dev/null; then
        BACKUP_DIR="$data_dir/backups"
        mkdir -p "$BACKUP_DIR"
        create_manual_backup
    else
        echo -e "${YELLOW}⚠️  Module backup chưa được load, bỏ qua backup${NC}"
    fi
    
    echo -e "\n${CYAN}🔄 Đang cập nhật N8N...${NC}"
    echo -e "${CYAN}   📥 Đang tải image N8N mới nhất...${NC}"
    
    if docker-compose -f "$compose_file" pull "$container_name" 2>/dev/null || docker-compose -f "$compose_file" pull; then
        echo -e "${GREEN}   ✅ Đã tải image N8N thành công${NC}"
    else
        echo -e "${RED}   ❌ Không thể tải image N8N mới${NC}"
        return 1
    fi
    
    echo -e "${CYAN}   🔄 Đang khởi động lại N8N với phiên bản mới...${NC}"
    
    if docker-compose -f "$compose_file" up -d "$container_name"; then
        echo -e "${GREEN}   ✅ Đã khởi động lại N8N thành công${NC}"
    else
        echo -e "${RED}   ❌ Lỗi khi khởi động lại N8N${NC}"
        return 1
    fi
    
    echo -e "\n${CYAN}⏳ Đang đợi N8N khởi động hoàn tất...${NC}"
    local port="${SELECTED_PORT:-5678}"
    local retry_count=0
    local max_retries=12
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}" | grep -q "200\|302\|401"; then
            break
        fi
        retry_count=$((retry_count + 1))
        echo -e "${CYAN}   ⏳ Đang đợi... ($retry_count/$max_retries)${NC}"
        sleep 5
    done
    
    echo -e "\n${CYAN}📋 Kiểm tra phiên bản sau cập nhật...${NC}"
    sleep 3
    local new_version=$(docker exec "$container_name" n8n --version 2>/dev/null || echo "Không xác định")
    echo -e "${GREEN}   Phiên bản mới: ${new_version}${NC}"
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                              ✅ CẬP NHẬT N8N HOÀN TẤT! ✅                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CYAN}📋 Tóm tắt cập nhật:${NC}"
    echo -e "${CYAN}   • Instance: ${instance_id}${NC}"
    echo -e "${CYAN}   • Domain: ${domain}${NC}"
    echo -e "${CYAN}   • Phiên bản cũ: ${current_version}${NC}"
    echo -e "${GREEN}   • Phiên bản mới: ${new_version}${NC}"
    
    log_message "SUCCESS" "Cập nhật N8N instance $instance_id thành công từ $current_version lên $new_version"
}
