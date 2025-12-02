#!/usr/bin/env bash

# Module Quản lý SSL
# Chứa các hàm liên quan đến cài đặt và quản lý SSL certificate

create_temporary_nginx_config() {
    # Sử dụng get_current_domain() làm source of truth
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
    fi
    
    # Fallback to global DOMAIN nếu get_current_domain không có kết quả
    if [ -z "$current_domain" ]; then
        current_domain="$DOMAIN"
    fi
    
    if [ -z "$current_domain" ]; then
        log_message "ERROR" "DOMAIN chưa được cấu hình"
        return 1
    fi
    
    # Sử dụng nginx_manager thay vì tạo config thủ công
    if type apply_nginx_config &>/dev/null; then
        log_message "INFO" "Cấu hình Nginx tạm thời (HTTP only) cho Let's Encrypt"
        apply_nginx_config "$current_domain" "true"  # force HTTP only
    else
        log_message "ERROR" "Module nginx_manager chưa được load"
        return 1
    fi
}

install_ssl_certificate_fresh() {
    # Sử dụng get_current_domain() làm source of truth
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
    fi
    
    # Fallback to global DOMAIN
    if [ -z "$current_domain" ]; then
        current_domain="$DOMAIN"
    fi
    
    if [ -z "$current_domain" ]; then
        log_message "ERROR" "DOMAIN chưa được cấu hình"
        return 1
    fi
    
    log_message "INFO" "Cài đặt SSL certificate mới cho $current_domain..."
    
    # Sử dụng ssl_manager để cài SSL
    if type install_ssl_certificate &>/dev/null; then
        echo -e "${CYAN}  • Đang cài đặt SSL certificate qua ssl_manager...${NC}"
        
        if install_ssl_certificate "$current_domain" "$EMAIL" "false"; then
            log_message "SUCCESS" "Cài đặt SSL certificate thành công"
            
            # Show certificate info
            if type get_ssl_info &>/dev/null; then
                echo ""
                get_ssl_info "$current_domain"
            fi
            
            return 0
        else
            log_message "ERROR" "Không thể cài đặt SSL certificate"
            return 1
        fi
    else
        log_message "ERROR" "Module ssl_manager chưa được load"
        return 1
    fi
}

configure_nginx_ssl() {
    # Sử dụng get_current_domain() làm source of truth
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
    fi
    
    # Fallback to global DOMAIN
    if [ -z "$current_domain" ]; then
        current_domain="$DOMAIN"
    fi
    
    if [ -z "$current_domain" ]; then
        log_message "ERROR" "DOMAIN chưa được cấu hình"
        return 1
    fi
    
    log_message "INFO" "Cấu hình Nginx với SSL..."
    
    local ssl_cert_path="/etc/letsencrypt/live/${current_domain}/fullchain.pem"
    local ssl_key_path="/etc/letsencrypt/live/${current_domain}/privkey.pem"
    
    if [ ! -f "$ssl_cert_path" ] || [ ! -f "$ssl_key_path" ]; then
        log_message "ERROR" "Không tìm thấy SSL certificate files"
        return 1
    fi
    
    # Sử dụng nginx_manager để cấu hình
    if type apply_nginx_config &>/dev/null; then
        log_message "INFO" "Cấu hình Nginx với SSL qua nginx_manager"
        apply_nginx_config "$current_domain" "false"  # With SSL
    else
        log_message "ERROR" "Module nginx_manager chưa được load"
        return 1
    fi
}

setup_ssl_auto_renewal() {
    log_message "INFO" "Thiết lập auto-renewal cho SSL..."
    
    if [ ! -f "/etc/systemd/system/certbot-renewal.service" ]; then
        sudo tee /etc/systemd/system/certbot-renewal.service > /dev/null <<EOF
[Unit]
Description=Certbot Renewal
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
    fi
    
    if [ ! -f "/etc/systemd/system/certbot-renewal.timer" ]; then
        sudo tee /etc/systemd/system/certbot-renewal.timer > /dev/null <<EOF
[Unit]
Description=Run certbot twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF
    fi
    
    sudo systemctl daemon-reload
    sudo systemctl enable certbot-renewal.timer
    sudo systemctl start certbot-renewal.timer
    
    log_message "SUCCESS" "Auto-renewal đã được thiết lập"
}

test_ssl_configuration() {
    # Sử dụng get_current_domain() làm source of truth
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
    fi
    
    # Fallback to global DOMAIN
    if [ -z "$current_domain" ]; then
        current_domain="$DOMAIN"
    fi
    
    if [ -z "$current_domain" ]; then
        log_message "ERROR" "DOMAIN chưa được cấu hình"
        return 1
    fi
    
    log_message "INFO" "Kiểm tra cấu hình SSL..."
    
    echo -e "\n${CYAN}🔍 KIỂM TRA KẾT NỐI SSL${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    local ipv4=$(get_server_ipv4)
    local ipv6=$(get_server_ipv6)
    
    local ipv4_status="⏭️  Bỏ qua"
    local ipv6_status="⏭️  Bỏ qua"
    
    if [ -n "$ipv4" ]; then
        echo -e "${CYAN}📡 Đang test HTTPS qua IPv4 ($ipv4)...${NC}"
        if curl -4 -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "https://$current_domain" 2>/dev/null | grep -q "200\|301\|302"; then
            ipv4_status="${GREEN}✅ Hoạt động tốt${NC}"
            log_message "SUCCESS" "HTTPS qua IPv4 hoạt động tốt"
        else
            ipv4_status="${RED}❌ Không kết nối được${NC}"
            log_message "WARN" "Không thể kết nối HTTPS qua IPv4"
        fi
    else
        ipv4_status="${YELLOW}⚠️  Không có IPv4${NC}"
    fi
    
    if [ -n "$ipv6" ]; then
        echo -e "${CYAN}📡 Đang test HTTPS qua IPv6 ($ipv6)...${NC}"
        if curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "https://$current_domain" 2>/dev/null | grep -q "200\|301\|302"; then
            ipv6_status="${GREEN}✅ Hoạt động tốt${NC}"
            log_message "SUCCESS" "HTTPS qua IPv6 hoạt động tốt"
        else
            ipv6_status="${YELLOW}⚠️  Không kết nối được (kiểm tra DNS AAAA record)${NC}"
            log_message "WARN" "Không thể kết nối HTTPS qua IPv6 - có thể cần DNS AAAA record"
        fi
    else
        ipv6_status="${YELLOW}⚠️  Không có IPv6${NC}"
    fi
    
    echo -e "\n${BOLD}${CYAN}📊 KẾT QUẢ KIỂM TRA:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}🌐 Domain:${NC} $current_domain"
    echo -e "${CYAN}🔐 HTTPS qua IPv4:${NC} $ipv4_status"
    echo -e "${CYAN}🔐 HTTPS qua IPv6:${NC} $ipv6_status"
    echo ""
    
    if command -v openssl &> /dev/null; then
        echo -e "${CYAN}📜 Thông tin certificate:${NC}"
        local cert_info=$(echo | openssl s_client -servername "$current_domain" -connect "$current_domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
        if [ -n "$cert_info" ]; then
            local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            echo -e "${GREEN}   Hết hạn: $not_after${NC}"
        fi
    fi
    
    echo -e "\n${CYAN}💡 Kiểm tra SSL grade chi tiết tại:${NC}"
    echo -e "${PURPLE}   https://www.ssllabs.com/ssltest/analyze.html?d=$current_domain${NC}"
    echo ""
}

# Interactive wrapper for SSL installation with user confirmation
# Internally calls install_ssl_certificate() from ssl_manager.sh
install_ssl_interactive() {
    local force_reinstall="${1:-false}"
    
    log_message "INFO" "Bắt đầu quá trình cài đặt SSL..."
    
    # Sử dụng get_current_domain() làm source of truth
    local current_domain=""
    if type get_current_domain &>/dev/null; then
        current_domain=$(get_current_domain)
    fi
    
    # Fallback to global DOMAIN
    if [ -z "$current_domain" ]; then
        current_domain="$DOMAIN"
    fi
    
    if [ -z "$current_domain" ]; then
        log_message "ERROR" "Domain chưa được cấu hình"
        return 1
    fi
    
    # Cập nhật biến global DOMAIN để các hàm khác sử dụng
    DOMAIN="$current_domain"
    
    # Sử dụng ssl_manager để cài SSL
    if ! type install_ssl_certificate &>/dev/null; then
        log_message "ERROR" "Module ssl_manager chưa được load"
        return 1
    fi
    
    if [ "$force_reinstall" = "true" ]; then
        echo -e "${BOLD}${YELLOW}🧹 XÓA TOÀN BỘ SSL CŨ...${NC}"
        
        if sudo certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
            log_message "INFO" "Tìm thấy SSL certificate cũ cho $DOMAIN"
            local cert_info=$(sudo certbot certificates 2>/dev/null | grep -A 10 "$DOMAIN")
            echo -e "${CYAN}$cert_info${NC}"
        fi
        
        if [ "$force_reinstall" != "true" ]; then
            echo -e "${YELLOW}Để cài SSL cho domain mới, cần xóa toàn bộ certificate cũ.${NC}"
            echo -e "${CYAN}1. Xóa toàn bộ SSL cũ và cài mới${NC}"
            echo -e "${CYAN}2. Giữ nguyên SSL hiện tại${NC}"
            echo -e "${CYAN}3. Hủy bỏ${NC}"
            read -p "$(echo -e ${CYAN}Lựa chọn [1/2/3]: ${NC})" ssl_choice
            
            case $ssl_choice in
                1) 
                    echo -e "${GREEN}✅ Sẽ xóa toàn bộ SSL cũ và cài mới${NC}"
                    ;;
                2)
                    log_message "INFO" "Giữ nguyên SSL hiện tại"
                    return 0
                    ;;
                *)
                    log_message "INFO" "Hủy bỏ cài đặt SSL"
                    return 0
                    ;;
            esac
        fi
        
        # Sử dụng ssl_manager để xóa SSL cũ
        if type clean_ssl_certificates &>/dev/null; then
            echo -e "${YELLOW}📋 Bước 1/3: Xóa toàn bộ SSL certificates cũ...${NC}"
            clean_ssl_certificates "$DOMAIN"
        fi
        
        echo -e "${YELLOW}📋 Bước 2/3: Cấu hình Nginx HTTP tạm thời...${NC}"
        create_temporary_nginx_config
        
        log_message "SUCCESS" "Đã xóa toàn bộ SSL cũ thành công"
    fi
    
    echo -e "${YELLOW}📋 Bước 3/3: Cài đặt SSL certificate mới...${NC}"
    
    # Sử dụng ssl_manager để cài SSL
    if install_ssl_certificate "$DOMAIN" "$EMAIL" "true"; then
        log_message "SUCCESS" "Cài đặt SSL certificate thành công"
        
        # Cấu hình Nginx với SSL
        configure_nginx_ssl
        
        # Setup auto-renewal
        if type setup_ssl_auto_renewal &>/dev/null; then
            setup_ssl_auto_renewal
        fi
        
        # Test SSL
        test_ssl_configuration
    else
        log_message "ERROR" "Không thể cài đặt SSL certificate"
        return 1
    fi
    
    log_message "SUCCESS" "Cài đặt SSL hoàn tất!"
    return 0
}

handle_ssl_menu() {
    while true; do
        clear
        print_banner
        
        echo -e "${BOLD}${CYAN}MENU QUẢN LÝ SSL${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}CÀI ĐẶT & CẤU HÌNH SSL${NC}              ${BOLD}${CYAN}BẢO TRÌ & KIỂM TRA${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Cài đặt SSL mới${NC}                   ${BOLD}${CYAN}4.${NC} ${WHITE}Cấu hình lại Nginx SSL${NC}"
        echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Xóa toàn bộ SSL & cài mới${NC}         ${BOLD}${CYAN}5.${NC} ${WHITE}Test SSL configuration${NC}"
        echo -e "  ${BOLD}${GREEN}3.${NC} ${WHITE}Gia hạn SSL${NC}                       ${BOLD}${CYAN}6.${NC} ${WHITE}Kiểm tra trạng thái SSL${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại menu chính${NC}"
        
        read -p "$(echo -e "${BOLD}${CYAN}Nhập lựa chọn [0-6]: ${NC}")" ssl_choice
        
        case $ssl_choice in
            1)
                echo -e "\n${BOLD}${GREEN}🔐 CÀI ĐẶT SSL MỚI...${NC}\n"
                if [ -z "$DOMAIN" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập domain: ${NC}")" DOMAIN
                fi
                if [ -z "$EMAIL" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}📧 Nhập email: ${NC}")" EMAIL
                fi
                install_ssl_interactive
                ;;
            2)
                echo -e "\n${BOLD}${RED}🗑️  XÓA TOÀN BỘ SSL & CÀI MỚI...${NC}\n"
                if [ -z "$DOMAIN" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập domain: ${NC}")" DOMAIN
                fi
                if [ -z "$EMAIL" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}📧 Nhập email: ${NC}")" EMAIL
                fi
                echo -e "${BOLD}${YELLOW}⚠️  CẢNH BÁO: Sẽ xóa toàn bộ SSL certificate cũ!${NC}"
                install_ssl_interactive "true"
                ;;
            3)
                echo -e "\n${BOLD}${GREEN}🔄 GIA HẠN SSL...${NC}\n"
                sudo certbot renew
                ;;
            4)
                echo -e "\n${BOLD}${CYAN}⚙️  CẤU HÌNH NGINX SSL...${NC}\n"
                if [ -z "$DOMAIN" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập domain: ${NC}")" DOMAIN
                fi
                configure_nginx_ssl
                ;;
            5)
                echo -e "\n${BOLD}${CYAN}🧪 TEST SSL CONFIGURATION...${NC}\n"
                if [ -z "$DOMAIN" ]; then
                    read -p "$(echo -e "${BOLD}${CYAN}🌐 Nhập domain: ${NC}")" DOMAIN
                fi
                test_ssl_configuration
                ;;
            6)
                echo -e "\n${BOLD}${CYAN}📊 KIỂM TRA TRẠNG THÁI SSL...${NC}\n"
                sudo certbot certificates
                ;;
            0)
                break
                ;;
            *)
                echo -e "\n${BOLD}${RED}❌ Lựa chọn không hợp lệ! Vui lòng chọn từ 0-6.${NC}"
                sleep 2
                ;;
        esac
        
        if [ "$ssl_choice" != "0" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
            read -p "$(echo -e "${BOLD}${YELLOW}⏸️  Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}
