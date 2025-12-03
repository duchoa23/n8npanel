# Changelog - N8N Panel v3.1

Bản tổng hợp tất cả tính năng của N8N Auto Installer & Manager Panel.

**Release Date:** 2025-12-03

---

## [v3.1] - 2025-12-03

### 🎯 MULTI-INSTANCE N8N

- **Chạy nhiều N8N instances** trên cùng 1 VPS
- Mỗi instance có **domain, port, database riêng biệt**
- **Instance Selector**: Giao diện chọn instance trực quan
  - Hiển thị bảng với ID, Domain, Status, Port
  - Tự động chọn nếu chỉ có 1 instance
  - Option hủy/quay lại
- **100% tính năng hỗ trợ multi-instance**:
  - Backup/Restore
  - SSL Management
  - Docker Management
  - N8N Management
  - Update
  - Uninstall
- **Install Module**: Cho phép tạo thêm instance khi đã có instance 1
- **Uninstall Module**: Cho phép chọn instance để xóa hoặc xóa tất cả
- **System Info**: Hiển thị danh sách tất cả instances

### 🔧 CẢI THIỆN CHẤT LƯỢNG

- Fix hook.py regex patterns (CRITICAL)
- Fix credentials format đúng (`n8n_inet<id>_<ip_sum>`)
- Đợi PostgreSQL healthy trước khi khởi động N8N
- Kiểm tra N8N respond trước khi cấu hình Nginx
- Hiển thị logs nếu container không khởi động được
- Sửa lỗi PID syntax trong lock files
- Thêm validation functions cho domain và env values
- Cải thiện race condition handling với postgres health checks
- Thêm log rotation mechanism để tránh đầy disk
- Tập trung log files vào `/var/log/n8npanel/`
- Thêm retry mechanism cho download_remote_manifest
- Thêm health check query thực tế cho safe_restart_postgres

### 🏗️ KIẾN TRÚC MODULAR

- **Cấu trúc modular** với common modules
- **Instance Selector Module** (`common/instance_selector.sh`)
- **Restart Manager** với postgres query validation
- **SSL Manager** với auto-renewal
- **Domain Manager** với validation
- **Wrapper scripts** cho automation:
  - `domain_change_wrapper.sh`
  - `nginx_config_wrapper.sh`
  - `ssl_install_wrapper.sh`

### ✨ TÍNH NĂNG CHÍNH

#### 1. Cài đặt N8N mới
- Cài đặt Docker, Docker Compose
- Cài đặt Nginx làm reverse proxy
- Cài đặt PostgreSQL database
- Cài đặt N8N với cấu hình tối ưu
- Tự động cài SSL Let's Encrypt

#### 2. Quản lý Backup
- Backup thủ công và tự động theo lịch (cron)
- Restore từ file backup
- Backup bao gồm: database, workflows, credentials
- Multi-instance support

#### 3. Quản lý SSL
- Cài đặt SSL Let's Encrypt
- Gia hạn SSL tự động
- Kiểm tra trạng thái SSL
- Hỗ trợ wildcard SSL
- Multi-instance support

#### 4. Quản lý Docker
- Xem trạng thái containers
- Start/Stop/Restart containers
- Xem logs
- Dọn dẹp Docker (images, volumes không dùng)
- Multi-instance support

#### 5. Quản lý N8N
- Reset mật khẩu user
- Thay đổi domain
- Cấu hình LDAP
- Bật/tắt MFA
- Xem thông tin đăng nhập
- Multi-instance support

#### 6. Xem thông tin hệ thống
- Thông tin server (CPU, RAM, Disk)
- Thông tin N8N (version, domain, port)
- Thông tin database
- Thông tin SSL
- Danh sách tất cả instances

#### 7. Cập nhật
- Cập nhật N8N lên version mới nhất
- Cập nhật Panel từ remote
- Quản lý cấu hình mạng (IPv4/IPv6)
- Multi-instance support

#### 8. Multi-Instance N8N
- Liệt kê tất cả instances
- Tạo instance mới
- Quản lý instances (start/stop/restart)
- Xóa instances

#### 9. Gỡ cài đặt
- Xóa instance cụ thể hoặc tất cả
- Tạo backup trước khi xóa
- Giữ lại Docker và Nginx

#### Webhook Server (hook.py)
- HTTP API server cho automation
- Endpoints: `/health`, `/change-domain`, `/install-ssl`, `/nginx-config`
- Regex validation cho inputs

---

## 📁 Cấu trúc Files

```
v3/
├── n8n.sh                          # Script chính
├── manifest.json                   # Thông tin version
├── hook.py                         # Webhook server
├── install_v3.sh                   # Script cài đặt
│
├── common/                         # Modules dùng chung
│   ├── utils.sh
│   ├── network.sh
│   ├── nginx_manager.sh
│   ├── ssl_manager.sh
│   ├── env_manager.sh
│   ├── domain_manager.sh
│   ├── restart_manager.sh
│   ├── instance_selector.sh
│   ├── domain_change_wrapper.sh
│   ├── nginx_config_wrapper.sh
│   └── ssl_install_wrapper.sh
│
├── 1_Cai_dat_n8n_moi/install.sh
├── 2_Quan_ly_Backup/backup.sh
├── 3_Quan_ly_SSL/ssl.sh
├── 4_Quan_ly_Docker_Container/docker.sh
├── 5_Quan_ly_N8N/manage.sh
├── 6_Xem_thong_tin_he_thong/system_info.sh
├── 7_Cap_nhat/update.sh
├── 8_Multi_Instance/multi_instance.sh
└── 9_Go_cai_dat/uninstall.sh
```

---

