// WebSocket流式翻译测试脚本 (Node.js)
// 使用方法: node scripts/test-websocket.js

const WebSocket = require('ws');
const http = require('http');

const BASE_URL = 'http://localhost:8080';
const WS_URL = 'ws://localhost:8080';
const EMAIL = 'test@example.com';
const PASSWORD = 'Test1234!';

// 颜色输出
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    cyan: '\x1b[36m',
    yellow: '\x1b[33m',
    gray: '\x1b[90m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// 登录获取Token
async function login() {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify({
            email: EMAIL,
            password: PASSWORD
        });

        const options = {
            hostname: 'localhost',
            port: 8080,
            path: '/api/v1/auth/login',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        };

        const req = http.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                if (res.statusCode === 200) {
                    const response = JSON.parse(data);
                    resolve(response.token);
                } else {
                    reject(new Error(`Login failed: ${res.statusCode} - ${data}`));
                }
            });
        });

        req.on('error', (e) => {
            reject(e);
        });

        req.write(postData);
        req.end();
    });
}

// WebSocket测试
async function testWebSocket() {
    log('\n========================================', 'cyan');
    log('  WebSocket流式翻译测试', 'cyan');
    log('========================================\n', 'cyan');

    try {
        // 登录获取Token
        log('正在登录获取Token...', 'cyan');
        const token = await login();
        log(`✅ 登录成功，Token已获取\n`, 'green');

        // 连接WebSocket
        const wsUrl = `${WS_URL}/api/v1/translate/stream?token=${token}`;
        log(`正在连接WebSocket: ${wsUrl}`, 'cyan');
        
        const ws = new WebSocket(wsUrl);

        ws.on('open', () => {
            log('✅ WebSocket连接已建立\n', 'green');

            // 发送翻译请求
            const testCases = [
                {
                    type: 'translate',
                    text: 'Hello, how are you?',
                    source_language: 'en',
                    target_language: 'zh'
                },
                {
                    type: 'translate',
                    text: '你好，世界',
                    source_language: 'zh',
                    target_language: 'en'
                }
            ];

            let currentTest = 0;
            let fullTranslation = '';

            function sendNextTest() {
                if (currentTest >= testCases.length) {
                    log('\n✅ 所有测试完成', 'green');
                    ws.close();
                    return;
                }

                const test = testCases[currentTest];
                fullTranslation = '';
                log(`\n测试 ${currentTest + 1}: 翻译 "${test.text}"`, 'cyan');
                log(`  源语言: ${test.source_language} -> 目标语言: ${test.target_language}`, 'gray');
                
                ws.send(JSON.stringify(test));
            }

            ws.on('message', (data) => {
                try {
                    const message = JSON.parse(data.toString());
                    
                    if (message.type === 'translation_chunk') {
                        fullTranslation += message.translated_text;
                        process.stdout.write(`\r   接收中: ${fullTranslation}`);
                    } else if (message.type === 'translation_complete') {
                        log(`\n✅ 翻译完成: ${message.translated_text}`, 'green');
                        currentTest++;
                        setTimeout(sendNextTest, 1000);
                    } else if (message.type === 'error') {
                        log(`\n❌ 错误: ${message.error}`, 'red');
                        currentTest++;
                        setTimeout(sendNextTest, 1000);
                    }
                } catch (e) {
                    log(`\n❌ 解析消息失败: ${e.message}`, 'red');
                }
            });

            ws.on('error', (error) => {
                log(`\n❌ WebSocket错误: ${error.message}`, 'red');
            });

            ws.on('close', () => {
                log('\n连接已关闭', 'gray');
                process.exit(0);
            });

            // 开始第一个测试
            sendNextTest();
        });

        ws.on('error', (error) => {
            log(`❌ 连接失败: ${error.message}`, 'red');
            log('请确保服务正在运行: docker-compose ps', 'yellow');
            process.exit(1);
        });

    } catch (error) {
        log(`❌ 测试失败: ${error.message}`, 'red');
        process.exit(1);
    }
}

// 运行测试
testWebSocket();

