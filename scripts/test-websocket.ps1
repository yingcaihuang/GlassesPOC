# WebSocket流式翻译测试脚本
# 使用方法: .\scripts\test-websocket.ps1

param(
    [string]$BaseUrl = "ws://localhost:8080",
    [string]$Email = "test@example.com",
    [string]$Password = "Test1234!"
)

# 需要先获取Token
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  WebSocket流式翻译测试" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# 先登录获取Token
Write-Host "正在登录获取Token..." -ForegroundColor Cyan
try {
    $loginBody = @{
        email = $Email
        password = $Password
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/v1/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        $token = $data.token
        Write-Host "✅ 登录成功，Token已获取`n" -ForegroundColor Green
    } else {
        Write-Host "❌ 登录失败" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ 登录失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "注意: PowerShell的WebSocket支持有限，建议使用以下方式测试:" -ForegroundColor Yellow
Write-Host "`n1. 使用浏览器控制台:" -ForegroundColor Cyan
Write-Host @"
   const token = 'YOUR_TOKEN';
   const ws = new WebSocket('ws://localhost:8080/api/v1/translate/stream?token=' + token);
   
   ws.onopen = () => {
     console.log('连接已建立');
     ws.send(JSON.stringify({
       type: 'translate',
       text: 'Hello, world!',
       source_language: 'en',
       target_language: 'zh'
     }));
   };
   
   ws.onmessage = (event) => {
     const data = JSON.parse(event.data);
     console.log('收到消息:', data);
     if (data.is_complete) {
       console.log('翻译完成:', data.translated_text);
       ws.close();
     }
   };
   
   ws.onerror = (error) => {
     console.error('错误:', error);
   };
"@ -ForegroundColor Gray

Write-Host "`n2. 使用Node.js脚本 (需要安装node):" -ForegroundColor Cyan
Write-Host "   运行: node scripts/test-websocket.js" -ForegroundColor Gray

Write-Host "`n3. 使用在线WebSocket测试工具:" -ForegroundColor Cyan
Write-Host "   https://www.websocket.org/echo.html" -ForegroundColor Gray
Write-Host "   连接地址: ws://localhost:8080/api/v1/translate/stream?token=$token" -ForegroundColor Gray

Write-Host "`n你的Token: $token" -ForegroundColor Green

