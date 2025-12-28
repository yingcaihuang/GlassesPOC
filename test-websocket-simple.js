const WebSocket = require('ws');

// First login to get token
const fetch = require('node-fetch');

async function testWebSocket() {
    try {
        console.log('1. Testing login...');
        const loginResponse = await fetch('http://localhost:3000/api/v1/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                email: 'betty@123.com',
                password: 'Betty@123.com'
            })
        });
        
        if (!loginResponse.ok) {
            throw new Error('Login failed');
        }
        
        const loginData = await loginResponse.json();
        const token = loginData.token;
        console.log('✓ Login successful, token:', token.substring(0, 20) + '...');
        
        console.log('2. Testing WebSocket connection...');
        const wsUrl = `ws://localhost:3000/api/v1/realtime/chat?token=${token}`;
        console.log('WebSocket URL:', wsUrl);
        
        const ws = new WebSocket(wsUrl);
        
        ws.on('open', function() {
            console.log('✓ WebSocket connection opened successfully!');
            
            // Send a test message
            const testMessage = {
                type: 'test',
                message: 'Hello WebSocket!'
            };
            
            console.log('Sending test message:', testMessage);
            ws.send(JSON.stringify(testMessage));
            
            // Close after 3 seconds
            setTimeout(() => {
                console.log('Closing WebSocket connection...');
                ws.close();
            }, 3000);
        });
        
        ws.on('message', function(data) {
            console.log('✓ Received message:', data.toString());
        });
        
        ws.on('error', function(error) {
            console.error('✗ WebSocket error:', error);
        });
        
        ws.on('close', function(code, reason) {
            console.log(`WebSocket closed: code=${code}, reason=${reason}`);
        });
        
    } catch (error) {
        console.error('Test failed:', error);
    }
}

testWebSocket();