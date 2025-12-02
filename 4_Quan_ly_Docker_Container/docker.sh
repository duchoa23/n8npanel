#!/usr/bin/env bash

# Module Quản lý Docker Container
# Chứa các hàm liên quan đến quản lý Docker containers, volumes, networks

show_docker_status() {
    echo -e "${CYAN}🐳 TRẠNG THÁI DOCKER CONTAINERS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    if command -v docker &> /dev/null; then
        if docker info &>/dev/null 2>&1; then
            echo ""
            echo -e "${BOLD}${GREEN}📦 CONTAINERS:${NC}"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Không có container nào"
            
            echo ""
            echo -e "${BOLD}${CYAN}💾 DOCKER VOLUMES:${NC}"
            local volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "(n8n|postgres)")
            if [ -n "$volumes" ]; then
                echo "$volumes" | while read vol; do
                    local size=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $3}' || echo "N/A")
                    echo -e "${GREEN}  • ${NC}$vol ${CYAN}($size)${NC}"
                done
            else
                echo "  Không tìm thấy volume n8n/postgres"
            fi
            
            echo ""
            echo -e "${BOLD}${PURPLE}🌐 DOCKER NETWORKS:${NC}"
            local networks=$(docker network ls --format "{{.Name}}" 2>/dev/null | grep -E "(n8n|bridge)")
            if [ -n "$networks" ]; then
                echo "$networks" | while read net; do
                    echo -e "${GREEN}  • ${NC}$net"
                done
            else
                echo "  Không tìm thấy network n8n"
            fi
            
            echo ""
            echo -e "${BOLD}${YELLOW}📊 DOCKER SYSTEM INFO:${NC}"
            docker system df 2>/dev/null || echo "Không thể lấy thông tin system"
        else
            echo -e "${RED}❌ Docker không hoạt động hoặc không có quyền truy cập${NC}"
            echo -e "${YELLOW}💡 Thử chạy: sudo systemctl start docker${NC}"
        fi
    else
        echo -e "${RED}❌ Docker chưa được cài đặt${NC}"
        echo -e "${YELLOW}💡 Sử dụng menu 'Cài đặt n8n mới' để cài Docker${NC}"
    fi
}

show_container_logs() {
    echo -e "${CYAN}📋 XEM LOGS CONTAINER${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if ! docker ps &>/dev/null; then
        echo -e "${RED}❌ Docker không hoạt động${NC}"
        return 1
    fi
    
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [ -z "$containers" ]; then
        echo -e "${YELLOW}⚠️  Không có container nào đang chạy${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${GREEN}Chọn container để xem logs:${NC}"
    echo ""
    
    local counter=1
    local container_array=()
    while IFS= read -r container; do
        container_array+=("$container")
        local status=$(docker ps --filter "name=$container" --format "{{.Status}}" 2>/dev/null)
        echo -e "${CYAN}$counter.${NC} $container ${GREEN}($status)${NC}"
        counter=$((counter + 1))
    done <<< "$containers"
    
    echo ""
    echo -e "${RED}0.${NC} Quay lại"
    echo ""
    
    read -p "$(echo -e "${BOLD}${CYAN}Chọn container [0-$((counter-1))]: ${NC}")" choice
    
    if [ "$choice" = "0" ]; then
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((counter-1)) ]; then
        local selected_container="${container_array[$((choice-1))]}"
        echo ""
        echo -e "${BOLD}${GREEN}📋 Logs của container: $selected_container${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Số dòng logs muốn xem (mặc định 50): ${NC}")" lines
        lines=${lines:-50}
        
        docker logs --tail "$lines" "$selected_container" 2>&1
    else
        echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
    fi
}

# Interactive container restart with menu
# Prioritizes safe_restart_*() functions from restart_manager.sh
restart_containers() {
    echo -e "${CYAN}🔄 KHỞI ĐỘNG LẠI CONTAINERS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if ! docker ps &>/dev/null; then
        echo -e "${RED}❌ Docker không hoạt động${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${YELLOW}Chọn container để restart:${NC}"
    echo -e "${CYAN}1.${NC} Restart n8n"
    echo -e "${CYAN}2.${NC} Restart postgres"
    echo -e "${CYAN}3.${NC} Restart tất cả (n8n + postgres)"
    echo -e "${RED}0.${NC} Quay lại"
    echo ""
    
    read -p "$(echo -e "${BOLD}${CYAN}Chọn [0-3]: ${NC}")" restart_choice
    
    case $restart_choice in
        1)
            echo -e "\n${CYAN}🔄 Đang restart n8n...${NC}"
            # Sử dụng hàm restart an toàn từ restart_manager (bắt buộc)
            if type safe_restart_n8n &>/dev/null; then
                safe_restart_n8n "true"
            else
                log_message "ERROR" "Module restart_manager chưa được load"
                echo -e "${RED}❌ Module restart_manager chưa được load${NC}"
                echo -e "${YELLOW}💡 Chạy thủ công: docker restart n8n${NC}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}🔄 Đang restart postgres...${NC}"
            # Sử dụng hàm restart an toàn từ restart_manager (bắt buộc)
            if type safe_restart_postgres &>/dev/null; then
                safe_restart_postgres
            else
                log_message "ERROR" "Module restart_manager chưa được load"
                echo -e "${RED}❌ Module restart_manager chưa được load${NC}"
                echo -e "${YELLOW}💡 Chạy thủ công: docker restart postgres${NC}"
            fi
            ;;
        3)
            echo -e "\n${CYAN}🔄 Đang restart tất cả containers...${NC}"
            # Sử dụng hàm restart an toàn từ restart_manager (bắt buộc)
            if type safe_restart_all &>/dev/null; then
                safe_restart_all
            else
                log_message "ERROR" "Module restart_manager chưa được load"
                echo -e "${RED}❌ Module restart_manager chưa được load${NC}"
                echo -e "${YELLOW}💡 Chạy thủ công: docker restart postgres && sleep 5 && docker restart n8n${NC}"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
            ;;
    esac
}

stop_containers() {
    echo -e "${CYAN}⏹️  DỪNG CONTAINERS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if ! docker ps &>/dev/null; then
        echo -e "${RED}❌ Docker không hoạt động${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${YELLOW}Chọn container để dừng:${NC}"
    echo -e "${CYAN}1.${NC} Dừng n8n"
    echo -e "${CYAN}2.${NC} Dừng postgres"
    echo -e "${CYAN}3.${NC} Dừng tất cả (n8n + postgres)"
    echo -e "${RED}0.${NC} Quay lại"
    echo ""
    
    read -p "$(echo -e "${BOLD}${CYAN}Chọn [0-3]: ${NC}")" stop_choice
    
    case $stop_choice in
        1)
            echo -e "\n${CYAN}⏹️  Đang dừng n8n...${NC}"
            if docker stop n8n 2>/dev/null; then
                echo -e "${GREEN}✅ Đã dừng n8n thành công${NC}"
                log_message "SUCCESS" "Đã dừng container n8n"
            else
                echo -e "${RED}❌ Không thể dừng n8n${NC}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}⏹️  Đang dừng postgres...${NC}"
            if docker stop postgres 2>/dev/null; then
                echo -e "${GREEN}✅ Đã dừng postgres thành công${NC}"
                log_message "SUCCESS" "Đã dừng container postgres"
            else
                echo -e "${RED}❌ Không thể dừng postgres${NC}"
            fi
            ;;
        3)
            echo -e "\n${CYAN}⏹️  Đang dừng tất cả containers...${NC}"
            docker stop n8n postgres 2>/dev/null
            echo -e "${GREEN}✅ Đã dừng tất cả containers${NC}"
            log_message "SUCCESS" "Đã dừng tất cả containers"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
            ;;
    esac
}

start_containers() {
    echo -e "${CYAN}▶️  KHỞI ĐỘNG CONTAINERS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    if ! docker ps -a &>/dev/null; then
        echo -e "${RED}❌ Docker không hoạt động${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${YELLOW}Chọn container để khởi động:${NC}"
    echo -e "${CYAN}1.${NC} Khởi động n8n"
    echo -e "${CYAN}2.${NC} Khởi động postgres"
    echo -e "${CYAN}3.${NC} Khởi động tất cả (postgres → n8n)"
    echo -e "${RED}0.${NC} Quay lại"
    echo ""
    
    read -p "$(echo -e "${BOLD}${CYAN}Chọn [0-3]: ${NC}")" start_choice
    
    case $start_choice in
        1)
            echo -e "\n${CYAN}▶️  Đang khởi động n8n...${NC}"
            if docker start n8n 2>/dev/null; then
                echo -e "${GREEN}✅ Đã khởi động n8n thành công${NC}"
                log_message "SUCCESS" "Đã khởi động container n8n"
            else
                echo -e "${RED}❌ Không thể khởi động n8n${NC}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}▶️  Đang khởi động postgres...${NC}"
            if docker start postgres 2>/dev/null; then
                echo -e "${GREEN}✅ Đã khởi động postgres thành công${NC}"
                log_message "SUCCESS" "Đã khởi động container postgres"
            else
                echo -e "${RED}❌ Không thể khởi động postgres${NC}"
            fi
            ;;
        3)
            echo -e "\n${CYAN}▶️  Đang khởi động containers theo thứ tự...${NC}"
            
            if docker start postgres 2>/dev/null; then
                echo -e "${GREEN}✅ Đã khởi động postgres${NC}"
            else
                echo -e "${YELLOW}⚠️  Không thể khởi động postgres${NC}"
            fi
            
            echo -e "${CYAN}⏳ Đợi postgres sẵn sàng...${NC}"
            sleep 5
            
            if docker start n8n 2>/dev/null; then
                echo -e "${GREEN}✅ Đã khởi động n8n${NC}"
            else
                echo -e "${YELLOW}⚠️  Không thể khởi động n8n${NC}"
            fi
            
            log_message "SUCCESS" "Đã khởi động tất cả containers"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Lựa chọn không hợp lệ${NC}"
            ;;
    esac
}

cleanup_docker_images() {
    echo -e "${BOLD}${YELLOW}🧹 DỌN DẸP DOCKER IMAGES CŨ...${NC}\n"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker chưa được cài đặt${NC}"
        return 1
    fi
    
    if ! docker info &>/dev/null; then
        echo -e "${RED}❌ Docker không hoạt động hoặc không có quyền truy cập${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 Thông tin Docker hiện tại:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    docker system df
    
    echo ""
    echo -e "${YELLOW}⚠️  Cảnh báo: Sẽ xóa các images không được sử dụng${NC}"
    read -p "$(echo -e "${YELLOW}Bạn chắc chắn chứ? (y/n): ${NC}")" cleanup_confirm
    
    if [[ "$cleanup_confirm" =~ ^[Yy]$ ]]; then
        echo -e "\n${CYAN}🚀 Đang dọn dẹp Docker images cũ...${NC}"
        
        local images_before=$(docker images -q | wc -l)
        local size_before=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep "Images" | awk '{print $2}' || echo "0B")
        
        if docker image prune -f; then
            echo -e "${GREEN}✅ Dọn dẹp Docker images thành công!${NC}"
            
            local images_after=$(docker images -q | wc -l)
            local size_after=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep "Images" | awk '{print $2}' || echo "0B")
            local images_removed=$((images_before - images_after))
            
            echo -e "\n${GREEN}📊 Kết quả dọn dẹp:${NC}"
            echo -e "${CYAN}   • Images trước khi dọn: ${images_before}${NC}"
            echo -e "${CYAN}   • Images sau khi dọn: ${images_after}${NC}"
            echo -e "${GREEN}   • Đã xóa: ${images_removed} images${NC}"
            echo -e "${CYAN}   • Dung lượng trước: ${size_before}${NC}"
            echo -e "${CYAN}   • Dung lượng sau: ${size_after}${NC}"
            
            log_message "SUCCESS" "Dọn dẹp Docker images: xóa $images_removed images"
        else
            echo -e "${RED}❌ Lỗi khi dọn dẹp Docker images${NC}"
            log_message "ERROR" "Lỗi khi dọn dẹp Docker images"
            return 1
        fi
    else
        echo -e "${YELLOW}ℹ️  Đã hủy tác vụ dọn dẹp Docker images${NC}"
        log_message "INFO" "Người dùng hủy tác vụ dọn dẹp Docker images"
    fi
}

handle_docker_menu() {
    while true; do
        clear
        print_banner
        
        echo -e "${BOLD}${CYAN}MENU QUẢN LÝ DOCKER CONTAINER${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}QUẢN LÝ CONTAINERS${NC}                  ${BOLD}${CYAN}THÔNG TIN & BẢO TRÌ${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}1.${NC} ${WHITE}Xem trạng thái Docker${NC}             ${BOLD}${CYAN}5.${NC} ${WHITE}Xem logs container${NC}"
        echo -e "  ${BOLD}${GREEN}2.${NC} ${WHITE}Khởi động containers${NC}              ${BOLD}${CYAN}6.${NC} ${WHITE}Dọn dẹp Docker images${NC}"
        echo -e "  ${BOLD}${GREEN}3.${NC} ${WHITE}Dừng containers${NC}"
        echo -e "  ${BOLD}${GREEN}4.${NC} ${WHITE}Restart containers${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}0.${NC} ${WHITE}Quay lại menu chính${NC}"
        
        read -p "$(echo -e "${BOLD}${CYAN}Chọn tùy chọn [0-6]: ${NC}")" docker_choice
        
        case $docker_choice in
            1)
                echo -e "\n${BOLD}${CYAN}📊 TRẠNG THÁI DOCKER...${NC}\n"
                show_docker_status
                ;;
            2)
                echo -e "\n${BOLD}${GREEN}▶️  KHỞI ĐỘNG CONTAINERS...${NC}\n"
                start_containers
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}⏹️  DỪNG CONTAINERS...${NC}\n"
                stop_containers
                ;;
            4)
                echo -e "\n${BOLD}${CYAN}🔄 RESTART CONTAINERS...${NC}\n"
                restart_containers
                ;;
            5)
                echo -e "\n${BOLD}${CYAN}📋 XEM LOGS...${NC}\n"
                show_container_logs
                ;;
            6)
                echo -e "\n${BOLD}${YELLOW}🧹 DỌN DẸP IMAGES...${NC}\n"
                cleanup_docker_images
                ;;
            0)
                break
                ;;
            *)
                echo -e "\n${BOLD}${RED}❌ Tùy chọn không hợp lệ! Vui lòng chọn từ 0-6.${NC}"
                sleep 2
                ;;
        esac
        
        if [ "$docker_choice" != "0" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}"
            read -p "$(echo -e "${BOLD}${YELLOW}⏸️  Nhấn Enter để tiếp tục...${NC}")"
        fi
    done
}
