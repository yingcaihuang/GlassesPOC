# PowerShell脚本 - 启动开发环境
# 使用方法: .\scripts\start-dev.ps1

Write-Host "启动智能眼镜后端开发环境..." -ForegroundColor Green

# 检查Docker是否运行
try {
    docker info | Out-Null
} catch {
    Write-Host "错误: Docker未运行，请先启动Docker Desktop" -ForegroundColor Red
    exit 1
}

# 检查.env文件
if (-not (Test-Path ".env")) {
    Write-Host "警告: .env文件不存在，将使用默认配置" -ForegroundColor Yellow
    Write-Host "提示: 可以创建.env文件来配置Azure OpenAI" -ForegroundColor Yellow
}

# 启动服务
Write-Host "`n启动Docker Compose服务..." -ForegroundColor Cyan
docker-compose up -d

# 等待服务就绪
Write-Host "`n等待服务启动..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# 检查服务状态
Write-Host "`n服务状态:" -ForegroundColor Cyan
docker-compose ps

# 显示日志
Write-Host "`n应用日志 (按Ctrl+C退出):" -ForegroundColor Cyan
docker-compose logs -f app

