#!/usr/bin/env python3
"""
Script đẩy folder v3 lên GitHub
Sử dụng: python push_to_github.py
"""

import os
import subprocess
import sys

def run_cmd(cmd, cwd=None):
    """Chạy command và trả về output"""
    print(f"  > {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0 and result.stderr:
        print(f"  ⚠️  {result.stderr.strip()}")
    return result.returncode == 0, result.stdout.strip()

def main():
    print("=" * 60)
    print("       PUSH V3 PANEL TO GITHUB")
    print("=" * 60)
    print()
    
    # Lấy đường dẫn thư mục hiện tại (v3)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    print(f"📁 Thư mục: {current_dir}")
    print()
    
    # Nhập thông tin GitHub
    repo_input = input("🔗 Nhập GitHub repo (vd: duchoa23/panel_n8n): ").strip()
    if not repo_input:
        print("❌ Repo không được để trống!")
        return
    
    # Xử lý input
    if repo_input.startswith("https://"):
        repo_url = repo_input
    elif repo_input.startswith("git@"):
        repo_url = repo_input
    else:
        repo_url = f"https://github.com/{repo_input}.git"
    
    print(f"📌 Repo URL: {repo_url}")
    print()
    
    # Nhập commit message
    commit_msg = input("💬 Commit message (Enter = 'Update v3 panel'): ").strip()
    if not commit_msg:
        commit_msg = "Update v3 panel"
    
    # Nhập branch
    branch = input("🌿 Branch (Enter = 'main'): ").strip()
    if not branch:
        branch = "main"
    
    print()
    print("=" * 60)
    print("🚀 Bắt đầu đẩy lên GitHub...")
    print("=" * 60)
    print()
    
    # Kiểm tra git đã cài chưa
    success, _ = run_cmd("git --version")
    if not success:
        print("❌ Git chưa được cài đặt!")
        return
    
    # Kiểm tra đã có .git chưa
    git_dir = os.path.join(current_dir, ".git")
    if not os.path.exists(git_dir):
        print("📦 Khởi tạo git repository...")
        run_cmd("git init", cwd=current_dir)
    
    # Tạo .gitignore nếu chưa có
    gitignore_path = os.path.join(current_dir, ".gitignore")
    if not os.path.exists(gitignore_path):
        print("📝 Tạo .gitignore...")
        with open(gitignore_path, "w") as f:
            f.write("""# Python
__pycache__/
*.py[cod]
*.pyo
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Temp
*.tmp
*.bak
*.zip
n8n_nginx.txt
n8n2_nginx.txt
""")
    
    # Add all files
    print("📥 Thêm tất cả files...")
    run_cmd("git add -A", cwd=current_dir)
    
    # Commit
    print(f"💾 Commit: {commit_msg}")
    run_cmd(f'git commit -m "{commit_msg}"', cwd=current_dir)
    
    # Kiểm tra remote origin
    success, remotes = run_cmd("git remote -v", cwd=current_dir)
    if "origin" in remotes:
        print("🔄 Cập nhật remote origin...")
        run_cmd(f"git remote set-url origin {repo_url}", cwd=current_dir)
    else:
        print("➕ Thêm remote origin...")
        run_cmd(f"git remote add origin {repo_url}", cwd=current_dir)
    
    # Đổi branch nếu cần
    print(f"🌿 Chuyển sang branch: {branch}")
    run_cmd(f"git branch -M {branch}", cwd=current_dir)
    
    # Push
    print(f"🚀 Đẩy lên GitHub ({branch})...")
    success, output = run_cmd(f"git push -u origin {branch} --force", cwd=current_dir)
    
    print()
    print("=" * 60)
    if success:
        print("✅ ĐÃ PUSH THÀNH CÔNG!")
        print(f"🔗 Xem tại: https://github.com/{repo_input}")
    else:
        print("⚠️  Có thể cần xác thực GitHub.")
        print("💡 Thử các cách sau:")
        print("   1. Dùng GitHub CLI: gh auth login")
        print("   2. Dùng Personal Access Token thay password")
        print("   3. Cấu hình SSH key")
    print("=" * 60)

if __name__ == "__main__":
    main()
