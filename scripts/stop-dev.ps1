# PowerShell脚本 - 停止开发环境
# 使用方法: .\scripts\stop-dev.ps1

Write-Host "停止智能眼镜后端开发环境..." -ForegroundColor Green

docker-compose down

Write-Host "`n服务已停止" -ForegroundColor Green

