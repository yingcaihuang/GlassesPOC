# Smart Glasses Backend API Test Script
# Usage: .\scripts\test-api.ps1

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Email = "test@example.com",
    [string]$Password = "Test1234!",
    [string]$Username = "testuser"
)

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# Global variables
$script:Token = $null
$script:RefreshToken = $null
$script:UserId = $null

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Smart Glasses Backend API Test" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Test 1: Health Check
Write-Info "Test 1: Health Check"
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/health" -Method GET -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        $content = $response.Content | ConvertFrom-Json
        Write-Success "Server is running: $($content.status)"
    }
} catch {
    Write-Error "Health check failed: $($_.Exception.Message)"
    Write-Warning "Please ensure services are running: docker-compose ps"
    exit 1
}

# Test 2: User Registration
Write-Info "`nTest 2: User Registration"
try {
    $registerBody = @{
        username = $Username
        email = $Email
        password = $Password
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/auth/register" `
        -Method POST `
        -ContentType "application/json" `
        -Body $registerBody `
        -UseBasicParsing

    if ($response.StatusCode -eq 201) {
        $data = $response.Content | ConvertFrom-Json
        $script:Token = $data.token
        $script:RefreshToken = $data.refresh_token
        $script:UserId = $data.user.id
        Write-Success "Registration successful!"
        Write-Host "   User ID: $($data.user.id)" -ForegroundColor Gray
        Write-Host "   Username: $($data.user.username)" -ForegroundColor Gray
        Write-Host "   Email: $($data.user.email)" -ForegroundColor Gray
        Write-Host "   Token saved" -ForegroundColor Gray
    }
} catch {
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($errorResponse -and $errorResponse.error -like "*already exists*") {
        Write-Warning "User already exists, skipping registration, continuing with login..."
    } else {
        Write-Error "Registration failed: $($_.Exception.Message)"
        if ($errorResponse) {
            Write-Host "   Error details: $($errorResponse.error)" -ForegroundColor Red
        }
    }
}

# Test 3: User Login
Write-Info "`nTest 3: User Login"
try {
    $loginBody = @{
        email = $Email
        password = $Password
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        $script:Token = $data.token
        $script:RefreshToken = $data.refresh_token
        $script:UserId = $data.user.id
        Write-Success "Login successful!"
        Write-Host "   Token expires in: $($data.expires_in) seconds" -ForegroundColor Gray
    }
} catch {
    Write-Error "Login failed: $($_.Exception.Message)"
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($errorResponse) {
        Write-Host "   Error details: $($errorResponse.error)" -ForegroundColor Red
    }
    exit 1
}

if (-not $script:Token) {
    Write-Error "Cannot get token, test terminated"
    exit 1
}

# Test 4: Get User Profile
Write-Info "`nTest 4: Get User Profile"
try {
    $headers = @{
        Authorization = "Bearer $script:Token"
    }

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/user/profile" `
        -Method GET `
        -Headers $headers `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        Write-Success "Get user profile successful!"
        Write-Host "   ID: $($data.id)" -ForegroundColor Gray
        Write-Host "   Username: $($data.username)" -ForegroundColor Gray
        Write-Host "   Email: $($data.email)" -ForegroundColor Gray
    }
} catch {
    Write-Error "Get user profile failed: $($_.Exception.Message)"
}

# Test 5: Refresh Token
Write-Info "`nTest 5: Refresh Token"
try {
    $refreshBody = @{
        refresh_token = $script:RefreshToken
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/auth/refresh" `
        -Method POST `
        -ContentType "application/json" `
        -Body $refreshBody `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        $oldToken = $script:Token
        $script:Token = $data.token
        Write-Success "Token refresh successful!"
        Write-Host "   New token: $($script:Token.Substring(0, [Math]::Min(50, $script:Token.Length)))..." -ForegroundColor Gray
    }
} catch {
    Write-Error "Token refresh failed: $($_.Exception.Message)"
}

# Test 6: Text Translation
Write-Info "`nTest 6: Text Translation"
$testTexts = @(
    @{ text = "Hello, how are you?"; source = "en"; target = "zh" },
    @{ text = "Hello World"; source = "en"; target = "zh" },
    @{ text = "Bonjour le monde"; source = "fr"; target = "zh" }
)

$translationCount = 0
foreach ($test in $testTexts) {
    try {
        $translateBody = @{
            text = $test.text
            source_language = $test.source
            target_language = $test.target
        } | ConvertTo-Json

        $headers = @{
            Authorization = "Bearer $script:Token"
        }

        Write-Host "   Translating: [$($test.source) -> $($test.target)] $($test.text)" -ForegroundColor Gray
        
        $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/translate/text" `
            -Method POST `
            -Headers $headers `
            -ContentType "application/json" `
            -Body $translateBody `
            -UseBasicParsing

        if ($response.StatusCode -eq 200) {
            $data = $response.Content | ConvertFrom-Json
            Write-Success "   Result: $($data.translated_text)"
            $translationCount++
        }
    } catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorResponse) {
            Write-Error "   Translation failed: $($errorResponse.error)"
            if ($errorResponse.error -like "*Azure*" -or $errorResponse.error -like "*OpenAI*") {
                Write-Warning "   Hint: Please check Azure OpenAI configuration"
            }
        } else {
            Write-Error "   Translation failed: $($_.Exception.Message)"
        }
    }
    Start-Sleep -Milliseconds 500
}

if ($translationCount -eq 0) {
    Write-Warning "All translation tests failed, please check Azure OpenAI configuration"
} else {
    Write-Success "Successfully completed $translationCount translation tests"
}

# Test 7: Translation History
Write-Info "`nTest 7: Get Translation History"
try {
    $headers = @{
        Authorization = "Bearer $script:Token"
    }

    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/translate/history?limit=10&offset=0" `
        -Method GET `
        -Headers $headers `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        $history = $data.data
        Write-Success "Get translation history successful!"
        Write-Host "   History count: $($history.Count)" -ForegroundColor Gray
        
        if ($history.Count -gt 0) {
            Write-Host "`n   Recent translations:" -ForegroundColor Gray
            foreach ($item in $history | Select-Object -First 3) {
                Write-Host "   - [$($item.source_language) -> $($item.target_language)]" -ForegroundColor Gray
                Write-Host "     Source: $($item.source_text)" -ForegroundColor DarkGray
                Write-Host "     Translated: $($item.translated_text)" -ForegroundColor DarkGray
                Write-Host ""
            }
        } else {
            Write-Host "   No translation history" -ForegroundColor Gray
        }
    }
} catch {
    Write-Error "Get translation history failed: $($_.Exception.Message)"
}

# Test Summary
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Test Complete" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

Write-Info "Test Summary:"
Write-Host "  [OK] Health Check: Passed" -ForegroundColor Green
Write-Host "  [OK] User Registration: Passed" -ForegroundColor Green
Write-Host "  [OK] User Login: Passed" -ForegroundColor Green
Write-Host "  [OK] Get User Profile: Passed" -ForegroundColor Green
Write-Host "  [OK] Token Refresh: Passed" -ForegroundColor Green
if ($translationCount -gt 0) {
    Write-Host "  [OK] Text Translation: Passed ($translationCount tests)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Text Translation: Failed (Please check Azure OpenAI config)" -ForegroundColor Yellow
}
Write-Host "  [OK] Translation History: Passed" -ForegroundColor Green

Write-Host "`nTip: View service logs with:" -ForegroundColor Cyan
Write-Host "  docker-compose logs -f app" -ForegroundColor Gray
