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

def push_to_gitlab():
    """Push lên GitLab"""
    print(f"\n🚀 Đang push lên GitLab branch '{BRANCH}'...")
    
    # Checkout hoặc tạo branch
    branches = run_cmd("git branch", check=False) or ""
    if BRANCH not in branches:
        run_cmd(f"git checkout -b {BRANCH}")
        print(f"✅ Đã tạo branch: {BRANCH}")
    else:
        current = run_cmd("git branch --show-current", check=False) or ""
        if current != BRANCH:
            run_cmd(f"git checkout {BRANCH}")
            print(f"✅ Đã chuyển sang branch: {BRANCH}")
    
    # Push
    print("\n⏳ Đang push...")
    result = run_cmd(f"git push -u {REMOTE_NAME} {BRANCH}", check=False)
    
    if result is not None:
        print(f"\n✅ Push thành công!")
        print(f"🔗 URL: https://{GITLAB_HOST}/{GITLAB_PROJECT}/-/tree/{BRANCH}")
        return True
    else:
        print("\n❌ Push thất bại!")
        print("\n💡 Gợi ý:")
        print("   1. Kiểm tra Access Token có đúng không")
        print("   2. Token cần có scope: write_repository")
        print(f"   3. Tạo token tại: https://{GITLAB_HOST}/-/profile/personal_access_tokens")
        return False

def main():
    print("=" * 60)
    print("   PUSH TO GITLAB - N8N Panel v3")
    print("=" * 60)
    print(f"\n📍 GitLab: https://{GITLAB_HOST}/{GITLAB_PROJECT}")
    print(f"📍 Branch: {BRANCH}")
    print(f"📍 Thư mục: {os.getcwd()}")
    
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
    print("💡 Token cần scope: write_repository (hoặc api)")
    print("💡 Token sẽ KHÔNG được lưu lại\n")
    
    token = getpass.getpass("🔑 Nhập Access Token: ")
    
    if not token:
        print("❌ Token không được để trống!")
        return 1
    
    # Cấu hình remote với token
    setup_remote_with_token(token)
    
    try:
        # Add và commit
        commit_msg = None
        if len(sys.argv) > 1:
            commit_msg = " ".join(sys.argv[1:])
        
        add_and_commit(commit_msg)
        
        # Push
        success = push_to_gitlab()
        
    finally:
        # Luôn xóa token khỏi remote URL sau khi push
        remove_token_from_remote()
    
    print("\n" + "=" * 60)
    if success:
        print("   ✅ HOÀN TẤT!")
    else:
        print("   ❌ CÓ LỖI XẢY RA")
    print("=" * 60)
    return 0 if success else 1

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
