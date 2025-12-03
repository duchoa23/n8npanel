#!/usr/bin/env bash

# Module Quản lý N8N
# Chứa các hàm liên quan đến quản lý user, MFA, LDAP, domain của N8N

reset_user_management() {
    log_message "INFO" "🔄 Bắt đầu reset quản lý người dùng..."
    
    # Luôn sử dụng hàm chuẩn từ domain_manager để đọc domain
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
        if [ -n "$current_domain" ]; then
            log_message "INFO" "📋 Đã đọc domain: $current_domain"
        fi
    fi
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^n8n$"; then
        log_message "ERROR" "❌ Container n8n không đang chạy"
        echo -e "${RED}❌ Container n8n cần phải đang chạy để thực hiện reset${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${YELLOW}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  KHÔNG THỂ HOÀN TÁC thao tác này!                                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    while true; do
        read -p "$(echo -e "${BOLD}${RED}Nhập 'XOA' để xác nhận hoặc 'HUY' để hủy: ${NC}")" confirm_input
        
        if [ "$confirm_input" = "XOA" ]; then
            echo -e "${GREEN}✅ Đã xác nhận reset user management${NC}"
            break
        elif [ "$confirm_input" = "HUY" ] || [ -z "$confirm_input" ]; then
            echo -e "${YELLOW}❌ Đã hủy thao tác reset${NC}"
            return 0
        else
            echo -e "${RED}❌ Vui lòng nhập chính xác 'XOA' hoặc 'HUY' để hủy${NC}"
        fi
    done
    
    echo -e "\n${BOLD}${CYAN}🔄 Đang thực hiện reset user management...${NC}"
    
    if timeout 60 docker exec n8n n8n user-management:reset 2>/dev/null; then
        log_message "SUCCESS" "✅ Đã reset user management thành công"
        
        echo -e "\n${BOLD}${CYAN}🔄 Đang restart n8n container để áp dụng thay đổi...${NC}"
        
        # Sử dụng hàm restart an toàn từ restart_manager (bắt buộc)
        if type safe_restart_n8n &>/dev/null; then
            safe_restart_n8n "true"
        else
            log_message "ERROR" "Module restart_manager chưa được load"
            echo -e "${RED}❌ Không thể restart container: Module restart_manager chưa được load${NC}"
            echo -e "${YELLOW}💡 Vui lòng chạy lệnh thủ công: docker restart n8n${NC}"
        fi
        
        echo -e "${BOLD}${GREEN}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                            ✅ RESET THÀNH CÔNG                               ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        if [ -n "$current_domain" ]; then
            echo -e "\n${BOLD}${CYAN}🌐 Thông tin truy cập:${NC}"
            echo -e "${WHITE}• URL: ${GREEN}https://$current_domain${NC}"
            echo -e "${WHITE}• Hoặc: ${GREEN}http://$(get_server_ip):5678${NC}"
        else
            echo -e "\n${BOLD}${CYAN}🌐 Truy cập n8n tại:${NC}"
            echo -e "${WHITE}• Local: ${GREEN}http://localhost:5678${NC}"
            echo -e "${WHITE}• External: ${GREEN}http://$(get_server_ip):5678${NC}"
        fi
    else
        log_message "ERROR" "❌ Lỗi khi reset user management"
        echo -e "${RED}❌ Không thể thực hiện reset. Kiểm tra logs để biết chi tiết.${NC}"
        return 1
    fi
}

disable_user_mfa() {
    log_message "INFO" "🔐 Bắt đầu tắt MFA cho người dùng..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^n8n$"; then
        log_message "ERROR" "❌ Container n8n không đang chạy"
        echo -e "${RED}❌ Container n8n cần phải đang chạy để tắt MFA${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           🔐 TẮT MFA CHO NGƯỜI DÙNG                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while true; do
        read -p "$(echo -e "${BOLD}${CYAN}📧 Nhập email của user cần tắt MFA: ${NC}")" user_email
        
        if [ -z "$user_email" ]; then
            echo -e "${RED}❌ Email không được để trống${NC}"
            continue
        fi
        
        if [[ "$user_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "${RED}❌ Định dạng email không hợp lệ${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}📋 Thông tin tắt MFA:${NC}"
    echo -e "${WHITE}👤 User email: ${CYAN}$user_email${NC}"
    echo ""
    
    while true; do
        read -p "$(echo -e "${BOLD}${YELLOW}Xác nhận tắt MFA cho user này? [Y/n]: ${NC}")" confirm
        confirm_upper=$(echo "$confirm" | tr '[:lower:]' '[:upper:]')
        
        if [ "$confirm_upper" = "Y" ] || [ "$confirm_upper" = "YES" ] || [ -z "$confirm" ]; then
            break
        elif [ "$confirm_upper" = "N" ] || [ "$confirm_upper" = "NO" ]; then
            echo -e "${YELLOW}❌ Đã hủy thao tác${NC}"
            return 0
        else
            echo -e "${RED}❌ Vui lòng nhập Y hoặc N${NC}"
        fi
    done
    
    echo -e "\n${BOLD}${CYAN}🔐 Đang tắt MFA cho user: $user_email...${NC}"
    
    if timeout 30 docker exec n8n n8n mfa:disable --email="$user_email" 2>/dev/null; then
        log_message "SUCCESS" "✅ Đã tắt MFA cho user: $user_email"
        
        echo -e "${BOLD}${GREEN}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                           ✅ TẮT MFA THÀNH CÔNG                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    else
        log_message "ERROR" "❌ Lỗi khi tắt MFA cho user: $user_email"
        echo -e "${RED}❌ Không thể tắt MFA. User có thể không tồn tại hoặc chưa bật MFA.${NC}"
        return 1
    fi
}

reset_ldap_settings() {
    log_message "INFO" "🔄 Bắt đầu reset cài đặt LDAP..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^n8n$"; then
        log_message "ERROR" "❌ Container n8n không đang chạy"
        echo -e "${RED}❌ Container n8n cần phải đang chạy để reset LDAP${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🔄 RESET CÀI ĐẶT LDAP                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    while true; do
        read -p "$(echo -e "${BOLD}${YELLOW}Xác nhận reset cài đặt LDAP? [Y/n]: ${NC}")" confirm
        confirm_upper=$(echo "$confirm" | tr '[:lower:]' '[:upper:]')
        
        if [ "$confirm_upper" = "Y" ] || [ "$confirm_upper" = "YES" ] || [ -z "$confirm" ]; then
            break
        elif [ "$confirm_upper" = "N" ] || [ "$confirm_upper" = "NO" ]; then
            echo -e "${YELLOW}❌ Đã hủy thao tác reset LDAP${NC}"
            return 0
        else
            echo -e "${RED}❌ Vui lòng nhập Y hoặc N${NC}"
        fi
    done
    
    echo -e "\n${BOLD}${CYAN}🔄 Đang reset cài đặt LDAP...${NC}"
    
    if timeout 30 docker exec n8n n8n ldap:reset 2>/dev/null; then
        log_message "SUCCESS" "✅ Đã reset cài đặt LDAP thành công"
        
        echo -e "${BOLD}${GREEN}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                          ✅ RESET LDAP THÀNH CÔNG                            ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    else
        log_message "ERROR" "❌ Lỗi khi reset LDAP"
        echo -e "${RED}❌ Không thể reset cài đặt LDAP. Kiểm tra logs để biết chi tiết.${NC}"
        return 1
    fi
}

# Interactive wrapper for domain change with user confirmation
# Internally calls change_domain_unified() from domain_manager.sh
change_domain_interactive() {
    log_message "INFO" "🌐 Bắt đầu thay đổi tên miền n8n..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^n8n$"; then
        log_message "ERROR" "❌ Container n8n không đang chạy"
        echo -e "${RED}❌ Container n8n cần phải đang chạy để thay đổi tên miền${NC}"
        return 1
    fi
    
    if [ ! -f "$N8N_DATA_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "❌ Không tìm thấy file docker-compose.yml"
        echo -e "${RED}❌ File docker-compose.yml không tồn tại tại: $N8N_DATA_DIR${NC}"
        return 1
    fi
    
    local server_ipv4=$(get_server_ipv4)
    local server_ipv6=$(get_server_ipv6)
    local server_ip=""
    
    if [ -n "$server_ipv4" ]; then
        server_ip="$server_ipv4"
    else
        server_ip="$server_ipv6"
    fi
    
    log_message "INFO" "📍 IPv4: ${server_ipv4:-"N/A"} | IPv6: ${server_ipv6:-"N/A"}"
    
    # Sử dụng hàm chuẩn từ domain_manager để đọc domain hiện tại
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
        log_message "INFO" "Domain hiện tại: ${current_domain:-"(chưa thiết lập)"}"
    else
        log_message "ERROR" "Module domain_manager chưa được load"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🌐 THAY ĐỔI TÊN MIỀN N8N                            ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ -n "$current_domain" ]; then
        echo -e "${BOLD}${YELLOW}📍 THÔNG TIN HIỆN TẠI:${NC}"
        echo -e "${GREEN}• Tên miền hiện tại: ${WHITE}${current_domain}${NC}"
        
        if [ -n "$server_ipv4" ] && [ -n "$server_ipv6" ]; then
            echo -e "${GREEN}• IPv4 máy chủ: ${WHITE}$server_ipv4${NC}"
            echo -e "${GREEN}• IPv6 máy chủ: ${WHITE}$server_ipv6${NC}"
            echo -e "${PURPLE}• Loại kết nối: ${WHITE}Dual-stack (IPv4 + IPv6)${NC}"
        elif [ -n "$server_ipv4" ]; then
            echo -e "${GREEN}• IPv4 máy chủ: ${WHITE}$server_ipv4${NC}"
            echo -e "${PURPLE}• Loại kết nối: ${WHITE}IPv4 only${NC}"
        elif [ -n "$server_ipv6" ]; then
            echo -e "${GREEN}• IPv6 máy chủ: ${WHITE}$server_ipv6${NC}"
            echo -e "${PURPLE}• Loại kết nối: ${WHITE}IPv6 only${NC}"
        fi
        echo ""
    fi
    
    # Nhập domain mới (bỏ xác nhận đầu tiên vì người dùng đã chọn menu này rồi)
    local new_domain=""
    
    while true; do
        read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập tên miền mới (ví dụ: n8n.example.com): ${NC}")" new_domain
        
        if [ -z "$new_domain" ]; then
            echo -e "${YELLOW}💡 Nhấn Ctrl+C để hủy hoặc nhập tên miền để tiếp tục${NC}"
            continue
        fi
        
        if [[ ! "$new_domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$ ]]; then
            echo -e "${RED}❌ Định dạng tên miền không hợp lệ!${NC}"
            continue
        fi
        
        if [ "$new_domain" = "$current_domain" ]; then
            echo -e "${YELLOW}⚠️  Tên miền mới giống với tên miền hiện tại!${NC}"
            continue
        fi
        
        break
    done
    
    echo -e "\n${BOLD}${CYAN}🔍 KIỂM TRA IP STATUS CỦA DOMAIN MỚI...${NC}"
    echo -e "${BOLD}${YELLOW}📋 THÔNG TIN THAY ĐỔI:${NC}"
    echo -e "• ${BOLD}Tên miền cũ:${NC} ${RED}${current_domain:-"Chưa thiết lập"}${NC}"
    echo -e "• ${BOLD}Tên miền mới:${NC} ${GREEN}$new_domain${NC}"
    
    if [ -n "$server_ipv4" ] && [ -n "$server_ipv6" ]; then
        echo -e "• ${BOLD}IPv4 máy chủ:${NC} ${CYAN}$server_ipv4${NC}"
        echo -e "• ${BOLD}IPv6 máy chủ:${NC} ${CYAN}$server_ipv6${NC}"
    elif [ -n "$server_ipv4" ]; then
        echo -e "• ${BOLD}IPv4 máy chủ:${NC} ${CYAN}$server_ipv4${NC}"
    elif [ -n "$server_ipv6" ]; then
        echo -e "• ${BOLD}IPv6 máy chủ:${NC} ${CYAN}$server_ipv6${NC}"
    fi
    echo ""
    
    local domain_check_result=""
    if check_domain_ip "$new_domain" "$server_ipv4" "$server_ipv6"; then
        domain_check_result="✅ PASS"
        echo -e "${GREEN}✅ Domain $new_domain đã trỏ đúng đến server${NC}"
    else
        local check_result=$?
        if [ $check_result -eq 1 ]; then
            echo -e "${YELLOW}❌ Đã hủy thao tác thay đổi tên miền${NC}"
            log_message "INFO" "Người dùng đã hủy thao tác tại bước kiểm tra domain"
            return 0
        fi
        domain_check_result="⚠️ WARNING"
        echo -e "${YELLOW}⚠️ Domain $new_domain chưa trỏ đúng đến server hoặc DNS chưa propagate${NC}"
        echo -e "${CYAN}💡 Bạn có thể tiếp tục nếu đã cấu hình DNS và đang chờ propagate${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}📊 TÓM TẮT KIỂM TRA:${NC}"
    echo -e "• ${BOLD}Domain check:${NC} $domain_check_result"
    echo -e "• ${BOLD}SSL sẽ được cài tự động:${NC} ${GREEN}✅ YES${NC}"
    echo -e "• ${BOLD}Container sẽ restart:${NC} ${GREEN}✅ YES${NC}"
    echo ""
    
    # Hỏi email cho SSL certificate
    local ssl_email=""
    while true; do
        read -p "$(echo -e "${BOLD}${CYAN}📧 Nhập email cho SSL certificate (Enter = admin@$new_domain): ${NC}")" ssl_email
        
        if [ -z "$ssl_email" ]; then
            ssl_email="admin@$new_domain"
            break
        fi
        
        if [[ "$ssl_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "${RED}❌ Định dạng email không hợp lệ${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Email SSL: $ssl_email${NC}"
    echo ""
    
    while true; do
        read -p "$(echo -e "${BOLD}${YELLOW}Xác nhận thực hiện thay đổi tên miền? [Y/n]: ${NC}")" confirm_final
        confirm_final_upper=$(echo "$confirm_final" | tr '[:lower:]' '[:upper:]')
        
        # Enter mặc định là Y
        if [ "$confirm_final_upper" = "Y" ] || [ "$confirm_final_upper" = "YES" ] || [ -z "$confirm_final" ]; then
            break
        elif [ "$confirm_final_upper" = "N" ] || [ "$confirm_final_upper" = "NO" ]; then
            echo -e "${YELLOW}❌ Đã hủy thao tác thay đổi tên miền${NC}"
            log_message "INFO" "Người dùng đã hủy thao tác tại bước xác nhận cuối"
            return 0
        else
            echo -e "${RED}❌ Vui lòng nhập Y (có) hoặc N (không)${NC}"
        fi
    done
    
    # Sử dụng domain_manager để thay đổi domain
    echo -e "\n${BOLD}${CYAN}🔄 SỬ DỤNG MODULE DOMAIN_MANAGER...${NC}"
    
    if type change_domain_unified &>/dev/null; then
        # Gọi hàm thống nhất từ domain_manager
        # Tham số: domain, email, skip_ssl, skip_confirmation
        change_domain_unified "$new_domain" "$ssl_email" "false" "true"
        local result=$?
        
        if [ $result -eq 0 ]; then
            DOMAIN="$new_domain"
            log_message "SUCCESS" "🎉 Hoàn tất thay đổi tên miền từ '${current_domain:-"chưa thiết lập"}' sang '$new_domain'"
        else
            log_message "ERROR" "❌ Lỗi khi thay đổi domain"
        fi
        
        return $result
    else
        log_message "ERROR" "Module domain_manager chưa được load"
        echo -e "${RED}❌ Không thể thay đổi domain: Module domain_manager chưa được load${NC}"
        return 1
    fi
}

handle_n8n_menu() {
    # Chọn instance nếu có nhiều instance
    if type select_instance_for_operation &>/dev/null; then
        if ! select_instance_for_operation "Chọn instance để quản lý"; then
            return 0
        fi
        # Cập nhật các biến global cho instance được chọn
        N8N_DATA_DIR="$SELECTED_DATA_DIR"
        COMPOSE_FILE="$SELECTED_COMPOSE_FILE"
        DOMAIN="$SELECTED_DOMAIN"
    fi
    
    while true; do
        clear
        print_banner
        
        # Hiển thị instance đang làm việc
        local current_instance="${SELECTED_INSTANCE:-1}"
        local current_domain="${SELECTED_DOMAIN:-$DOMAIN}"
        local current_container="${SELECTED_CONTAINER:-n8n}"
        
        echo -e "${BOLD}${CYAN}MENU QUẢN LÝ N8N${NC}"
        echo -e "${YELLOW}📌 Instance: ${current_instance} | Domain: ${current_domain} | Container: ${current_container}${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}QUẢN LÝ NGƯỜI DÙNG${NC}                   ${BOLD}${CYAN}CÀI ĐẶT & BẢO MẬT${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Reset quản lý tài khoản${NC}           ${BOLD}${CYAN}3.${NC} ${WHITE}Reset cài đặt LDAP${NC}"
        echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Tắt MFA cho người dùng${NC}            ${BOLD}${CYAN}4.${NC} ${WHITE}Thay đổi tên miền${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại menu chính${NC}"
        
        read -p "$(echo -e "${BOLD}${CYAN}Chọn tùy chọn [0-4]: ${NC}")" n8n_choice
        
        case $n8n_choice in
            1)
                echo -e "\n${BOLD}${GREEN}🔄 RESET QUẢN LÝ TÀI KHOẢN...${NC}\n"
                reset_user_management_for_instance "$current_container"
                ;;
            2)
                echo -e "\n${BOLD}${GREEN}🔐 TẮT MFA CHO NGƯỜI DÙNG...${NC}\n"
                disable_user_mfa_for_instance "$current_container"
                ;;
            3)
                echo -e "\n${BOLD}${GREEN}🔄 RESET CÀI ĐẶT LDAP...${NC}\n"
                reset_ldap_settings_for_instance "$current_container"
                ;;
            4)
                echo -e "\n${BOLD}${GREEN}🌐 THAY ĐỔI TÊN MIỀN...${NC}\n"
                change_domain_interactive
                ;;
            0)
                break
                ;;
            *)
                echo -e "\n${BOLD}${RED}❌ Tùy chọn không hợp lệ! Vui lòng chọn từ 0-4.${NC}"
                sleep 2
                ;;
        esac
        
        if [ "$n8n_choice" != "0" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
            read -p "$(echo -e "${BOLD}${YELLOW}⏸️  Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}

# Wrapper functions cho multi-instance
reset_user_management_for_instance() {
    local container="${1:-n8n}"
    # Gọi hàm gốc với container name
    reset_user_management
}

disable_user_mfa_for_instance() {
    local container="${1:-n8n}"
    disable_user_mfa
}

reset_ldap_settings_for_instance() {
    local container="${1:-n8n}"
    reset_ldap_settings
}
