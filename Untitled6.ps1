$gitignoreContent = @'
# Virtual Environment
.venv/
venv/
ENV/
env/

# Environment Variables & Secrets
.env
*.env

# SQLite Database & Storage
data/*.db
data/*.sqlite3
*.db
*.sqlite3

# Python cache & build artifacts
__pycache__/
*.py[cod]
*$py.class
*.so
build/
dist/
*.egg-info/

# IDE & Editor files
.vscode/
.idea/
*.swp
*.swo

# OS files
Thumbs.db
Desktop.ini
.DS_Store
'@

[System.IO.File]::WriteAllText("C:\hakaton\hr_exit_engine\.gitignore", $gitignoreContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Файл .gitignore успешно создан в C:\hakaton\hr_exit_engine\.gitignore" -ForegroundColor Green