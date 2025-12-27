# PowerShell脚本 - 清理开发环境（包括数据）
# 使用方法: .\scripts\clean-dev.ps1

Write-Host "警告: 这将删除所有数据卷！" -ForegroundColor Red
$confirm = Read-Host "确认删除? (y/N)"

if ($confirm -eq "y" -or $confirm -eq "Y") {
    Write-Host "`n停止并删除所有容器和数据卷..." -ForegroundColor Yellow
    docker-compose down -v
    Write-Host "`n清理完成" -ForegroundColor Green
} else {
    Write-Host "操作已取消" -ForegroundColor Yellow
}

