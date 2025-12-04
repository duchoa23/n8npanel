#!/usr/bin/env python3
"""
Script đẩy code lên GitLab
GitLab: https://gitlabs.inet.vn/donv/onescript
Branch: v3

Yêu cầu nhập Access Token mỗi lần push (không lưu)
"""

import subprocess
import os
import sys
import getpass

# Cấu hình
GITLAB_HOST = "gitlabs.inet.vn"
GITLAB_PROJECT = "donv/onescript"
BRANCH = "v3"
REMOTE_NAME = "origin"
USERNAME = "donv"  # Username GitLab của bạn

def run_cmd(cmd, check=True, capture=True):
    """Chạy command và trả về output"""
    print(f"  → {cmd}")
    if capture:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if check and result.returncode != 0:
            print(f"  ❌ Lỗi: {result.stderr}")
            return None
        return result.stdout.strip()
    else:
        result = subprocess.run(cmd, shell=True)
        return result.returncode == 0

def check_git():
    """Kiểm tra git đã cài đặt chưa"""
    result = run_cmd("git --version", check=False)
    if result is None:
        print("❌ Git chưa được cài đặt!")
        print("💡 Cài đặt: https://git-scm.com/downloads")
        return False
    print(f"✅ {result}")
    return True

def init_repo():
    """Khởi tạo git repo nếu chưa có"""
    if not os.path.exists(".git"):
        print("\n📁 Khởi tạo Git repository...")
        run_cmd("git init")
        print("✅ Đã khởi tạo repo")
    else:
        print("✅ Git repo đã tồn tại")

def setup_remote_with_token(token):
    """Cấu hình remote GitLab với token trong URL"""
    print("\n🔗 Cấu hình remote...")
    
    # URL với token embedded (không lưu vào credential store)
    remote_url = f"https://{USERNAME}:{token}@{GITLAB_HOST}/{GITLAB_PROJECT}.git"
    
    # Kiểm tra remote đã tồn tại chưa
    remotes = run_cmd("git remote -v", check=False) or ""
    
    if REMOTE_NAME in remotes:
        # Cập nhật URL với token mới
        run_cmd(f"git remote set-url {REMOTE_NAME} {remote_url}")
        print(f"✅ Đã cập nhật remote với token")
    else:
        run_cmd(f"git remote add {REMOTE_NAME} {remote_url}")
        print(f"✅ Đã thêm remote với token")

def remove_token_from_remote():
    """Xóa token khỏi remote URL sau khi push"""
    print("\n🔒 Xóa token khỏi remote URL...")
    clean_url = f"https://{GITLAB_HOST}/{GITLAB_PROJECT}.git"
    run_cmd(f"git remote set-url {REMOTE_NAME} {clean_url}")
    print("✅ Đã xóa token khỏi cấu hình")

def create_gitignore():
    """Tạo .gitignore nếu chưa có"""
    if not os.path.exists(".gitignore"):
        print("\n📝 Tạo .gitignore...")
        with open(".gitignore", "w") as f:
            f.write("""# Python
__pycache__/
*.py[cod]
*.pyo
.env

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Temp
*.tmp
*.bak
*.backup.*
""")
        print("✅ Đã tạo .gitignore")

def add_and_commit(message=None):
    """Add và commit changes"""
    print("\n📦 Chuẩn bị commit...")
    
    # Add tất cả files
    run_cmd("git add -A")
    
    # Kiểm tra có gì để commit không
    status = run_cmd("git status --porcelain", check=False) or ""
    
    if not status:
        print("ℹ️  Không có thay đổi nào để commit")
        return False
    
    # Hiển thị files sẽ commit
    print("\n📋 Files sẽ được commit:")
    lines = [l for l in status.split("\n") if l]
    for line in lines[:20]:
        print(f"   {line}")
    if len(lines) > 20:
        print(f"   ... và {len(lines) - 20} files khác")
    
    # Lấy commit message
    if not message:
        message = input("\n💬 Nhập commit message (Enter để dùng mặc định): ").strip()
        if not message:
            message = "Update N8N Panel v3.1"
    
    # Commit
    run_cmd(f'git commit -m "{message}"')
    print(f"✅ Đã commit: {message}")
    return True

def push_to_gitlab(branch=None):
    """Push lên GitLab"""
    target_branch = branch or BRANCH
    print(f"\n🚀 Đang push lên GitLab branch '{target_branch}'...")
    
    # Checkout hoặc tạo branch
    branches = run_cmd("git branch", check=False) or ""
    if target_branch not in branches:
        run_cmd(f"git checkout -b {target_branch}")
        print(f"✅ Đã tạo branch: {target_branch}")
    else:
        current = run_cmd("git branch --show-current", check=False) or ""
        if current != target_branch:
            run_cmd(f"git checkout {target_branch}")
            print(f"✅ Đã chuyển sang branch: {target_branch}")
    
    # Push
    print("\n⏳ Đang push...")
    result = run_cmd(f"git push -u {REMOTE_NAME} {target_branch}", check=False)
    
    if result is not None:
        print(f"\n✅ Push thành công!")
        print(f"🔗 URL: https://{GITLAB_HOST}/{GITLAB_PROJECT}/-/tree/{target_branch}")
        return True
    else:
        print("\n❌ Push thất bại!")
        print("\n💡 Gợi ý:")
        print("   1. Kiểm tra Access Token có đúng không")
        print("   2. Token cần có scope: write_repository")
        print(f"   3. Tạo token tại: https://{GITLAB_HOST}/-/profile/personal_access_tokens")
        return False

def list_remote_branches():
    """Liệt kê các branch trên remote"""
    print("\n📋 Đang lấy danh sách branches từ remote...")
    run_cmd(f"git fetch {REMOTE_NAME}", check=False)
    branches = run_cmd(f"git branch -r", check=False) or ""
    
    branch_list = []
    for line in branches.split("\n"):
        line = line.strip()
        if line and "->" not in line:  # Bỏ qua HEAD pointer
            # Loại bỏ prefix "origin/"
            branch_name = line.replace(f"{REMOTE_NAME}/", "")
            branch_list.append(branch_name)
    
    return branch_list

def delete_remote_branch(branch_name):
    """Xóa branch trên remote"""
    print(f"\n🗑️  Đang xóa branch '{branch_name}' trên remote...")
    
    # Xóa trên remote
    result = run_cmd(f"git push {REMOTE_NAME} --delete {branch_name}", check=False)
    
    if result is not None:
        print(f"✅ Đã xóa branch '{branch_name}' trên remote")
        
        # Xóa local branch nếu có
        local_branches = run_cmd("git branch", check=False) or ""
        if branch_name in local_branches:
            current = run_cmd("git branch --show-current", check=False) or ""
            if current == branch_name:
                # Chuyển sang branch khác trước khi xóa
                run_cmd(f"git checkout main", check=False) or run_cmd(f"git checkout master", check=False)
            run_cmd(f"git branch -D {branch_name}", check=False)
            print(f"✅ Đã xóa branch '{branch_name}' local")
        
        return True
    else:
        print(f"❌ Không thể xóa branch '{branch_name}'")
        return False

def manage_branches():
    """Menu quản lý branches"""
    branches = list_remote_branches()
    
    if not branches:
        print("ℹ️  Không có branch nào trên remote")
        return
    
    print("\n" + "=" * 50)
    print("   DANH SÁCH BRANCHES TRÊN REMOTE")
    print("=" * 50)
    
    for i, branch in enumerate(branches, 1):
        protected = " ⚠️ (protected)" if branch in ["main", "master"] else ""
        print(f"   {i}. {branch}{protected}")
    
    print(f"\n   0. Quay lại")
    print("=" * 50)
    
    choice = input("\n🗑️  Nhập số thứ tự branch cần XÓA (0 để quay lại): ").strip()
    
    if choice == "0" or not choice:
        return
    
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(branches):
            branch_to_delete = branches[idx]
            
            # Cảnh báo nếu là branch protected
            if branch_to_delete in ["main", "master"]:
                print(f"\n⚠️  CẢNH BÁO: '{branch_to_delete}' thường là branch chính!")
            
            confirm = input(f"\n⚠️  Xác nhận XÓA branch '{branch_to_delete}'? (yes/no): ").strip().lower()
            
            if confirm == "yes":
                delete_remote_branch(branch_to_delete)
            else:
                print("ℹ️  Đã hủy xóa branch")
        else:
            print("❌ Số không hợp lệ")
    except ValueError:
        print("❌ Vui lòng nhập số")

def show_menu():
    """Hiển thị menu chính"""
    print("\n" + "=" * 50)
    print("   GITLAB MANAGER - N8N Panel")
    print("=" * 50)
    print(f"\n📍 GitLab: https://{GITLAB_HOST}/{GITLAB_PROJECT}")
    print(f"📍 Thư mục: {os.getcwd()}")
    print("\n" + "-" * 50)
    print("   1. 🚀 Push code lên GitLab")
    print("   2. 🗑️  Xóa branch trên remote")
    print("   3. 📋 Xem danh sách branches")
    print("   0. ❌ Thoát")
    print("-" * 50)
    
    return input("\nChọn chức năng [0-3]: ").strip()

def do_push(token):
    """Thực hiện push"""
    # Hỏi branch
    target_branch = input(f"\n📌 Nhập tên branch (Enter = '{BRANCH}'): ").strip()
    if not target_branch:
        target_branch = BRANCH
    
    # Add và commit
    commit_msg = input("\n💬 Nhập commit message (Enter = mặc định): ").strip()
    if not commit_msg:
        commit_msg = "Update N8N Panel v3.1"
    
    add_and_commit(commit_msg)
    
    # Push
    return push_to_gitlab(target_branch)

def main():
    print("=" * 60)
    print("   GITLAB MANAGER - N8N Panel v3")
    print("=" * 60)
    
    # Kiểm tra git
    print("\n🔍 Kiểm tra Git...")
    if not check_git():
        return 1
    
    # Khởi tạo repo
    init_repo()
    
    # Tạo .gitignore
    create_gitignore()
    
    # Yêu cầu nhập Access Token
    print("\n" + "=" * 60)
    print("🔐 NHẬP GITLAB ACCESS TOKEN")
    print("=" * 60)
    print(f"💡 Tạo token tại: https://{GITLAB_HOST}/-/profile/personal_access_tokens")
    print("💡 Token cần scope: write_repository hoặc api")
    print("💡 Token sẽ KHÔNG được lưu lại\n")
    
    token = getpass.getpass("🔑 Nhập Access Token: ")
    
    if not token:
        print("❌ Token không được để trống!")
        return 1
    
    # Cấu hình remote với token
    setup_remote_with_token(token)
    
    success = True
    try:
        while True:
            choice = show_menu()
            
            if choice == "1":
                success = do_push(token)
            elif choice == "2":
                manage_branches()
            elif choice == "3":
                branches = list_remote_branches()
                if branches:
                    print("\n📋 Branches trên remote:")
                    for b in branches:
                        print(f"   • {b}")
                else:
                    print("ℹ️  Không có branch nào")
                input("\nNhấn Enter để tiếp tục...")
            elif choice == "0":
                break
            else:
                print("❌ Lựa chọn không hợp lệ")
        
    finally:
        # Luôn xóa token khỏi remote URL
        remove_token_from_remote()
    
    print("\n" + "=" * 60)
    print("   👋 TẠM BIỆT!")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  Đã hủy bởi người dùng")
        # Xóa token nếu đã set
        try:
            remove_token_from_remote()
        except:
            pass
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Lỗi: {e}")
        # Xóa token nếu đã set
        try:
            remove_token_from_remote()
        except:
            pass
        sys.exit(1)
