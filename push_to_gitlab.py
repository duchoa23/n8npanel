#!/usr/bin/env python3
"""
Script đẩy code lên GitLab
GitLab: https://gitlabs.inet.vn/donv/onescript
Branch: v3
"""

import subprocess
import os
import sys

# Cấu hình
GITLAB_URL = "https://gitlabs.inet.vn/donv/onescript.git"
BRANCH = "v3"
REMOTE_NAME = "origin"

def run_cmd(cmd, check=True):
    """Chạy command và trả về output"""
    print(f"  → {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"  ❌ Lỗi: {result.stderr}")
        return None
    return result.stdout.strip()

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

def setup_remote():
    """Cấu hình remote GitLab"""
    print("\n🔗 Cấu hình remote...")
    
    # Kiểm tra remote đã tồn tại chưa
    remotes = run_cmd("git remote -v", check=False) or ""
    
    if REMOTE_NAME in remotes:
        # Cập nhật URL nếu khác
        if GITLAB_URL not in remotes:
            run_cmd(f"git remote set-url {REMOTE_NAME} {GITLAB_URL}")
            print(f"✅ Đã cập nhật remote URL: {GITLAB_URL}")
        else:
            print(f"✅ Remote đã được cấu hình: {GITLAB_URL}")
    else:
        run_cmd(f"git remote add {REMOTE_NAME} {GITLAB_URL}")
        print(f"✅ Đã thêm remote: {GITLAB_URL}")

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
    for line in status.split("\n")[:20]:  # Giới hạn 20 dòng
        if line:
            print(f"   {line}")
    if len(status.split("\n")) > 20:
        print(f"   ... và {len(status.split(chr(10))) - 20} files khác")
    
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
    print("\n⏳ Đang push... (có thể cần nhập username/password)")
    result = subprocess.run(
        f"git push -u {REMOTE_NAME} {BRANCH}",
        shell=True,
        capture_output=False  # Hiển thị prompt nhập password
    )
    
    if result.returncode == 0:
        print(f"\n✅ Push thành công!")
        print(f"🔗 URL: https://gitlabs.inet.vn/donv/onescript/-/tree/{BRANCH}")
        return True
    else:
        print("\n❌ Push thất bại!")
        print("\n💡 Gợi ý:")
        print("   1. Kiểm tra username/password GitLab")
        print("   2. Tạo Personal Access Token: Settings → Access Tokens")
        print("   3. Dùng token thay password khi push")
        print(f"\n   Hoặc cấu hình credential:")
        print(f"   git config credential.helper store")
        return False

def setup_credential_helper():
    """Cấu hình lưu credential"""
    print("\n🔐 Cấu hình credential helper...")
    choice = input("Lưu credential để không phải nhập lại? (y/n): ").strip().lower()
    if choice == 'y':
        run_cmd("git config credential.helper store")
        print("✅ Credential sẽ được lưu sau lần đăng nhập đầu tiên")

def main():
    print("=" * 60)
    print("   PUSH TO GITLAB - N8N Panel v3")
    print("=" * 60)
    print(f"\n📍 GitLab: {GITLAB_URL}")
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
    
    # Cấu hình remote
    setup_remote()
    
    # Hỏi có muốn cấu hình credential không
    setup_credential_helper()
    
    # Add và commit
    commit_msg = None
    if len(sys.argv) > 1:
        commit_msg = " ".join(sys.argv[1:])
    
    add_and_commit(commit_msg)
    
    # Push
    push_to_gitlab()
    
    print("\n" + "=" * 60)
    print("   HOÀN TẤT!")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  Đã hủy bởi người dùng")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Lỗi: {e}")
        sys.exit(1)
