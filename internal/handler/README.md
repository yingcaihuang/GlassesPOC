# WebSocket Handler Implementation

## Overview

This document describes the implementation of the WebSocket handler for GPT Realtime API integration.

## Features Implemented

### 1. JWT Token Authentication (Requirements 2.2, 2.3)
- WebSocket connections are protected by JWT token validation
- Invalid tokens are rejected with appropriate error messages
- User context is extracted from validated tokens

### 2. Cross-Origin Support (Requirement 2.4)
- Development environment allows cross-origin WebSocket connections
- Production environment should implement stricter origin checking

### 3. Automatic GPT API Connection (Requirement 2.5)
- Upon successful WebSocket connection, automatically connects to GPT Realtime API
- Session configuration is sent automatically
- Connection status is communicated to the client

### 4. Message Processing
- **audio_data**: Validates and forwards audio data to GPT API
- **commit_audio**: Commits audio buffer for processing
- **clear_audio**: Clears the audio buffer
- **ping/pong**: Heartbeat mechanism for connection health
- **get_status**: Returns connection status information

### 5. Error Handling
- Comprehensive error handling for all operations
- User-friendly error messages sent to clients
- Automatic connection recovery mechanisms
- Proper logging for debugging

### 6. Connection Management
- Heartbeat/ping-pong mechanism to detect disconnections
- Proper connection cleanup on disconnect
- Read/write timeouts to prevent hanging connections
- Connection status monitoring

## Message Types

### Client Messages
```json
{
  "type": "audio_data",
  "audio": "base64-encoded-audio-data",
  "session_id": "optional-session-id"
}
```

### Server Messages
```json
{
  "type": "audio_received",
  "data": {
    "size": 1024,
    "timestamp": 1640995200000
  },
  "error": "",
  "timestamp": 1640995200000
}
```

## Configuration

### Buffer Sizes
- Read Buffer: 4KB (optimized for audio data)
- Write Buffer: 4KB (optimized for audio responses)

### Timeouts
- Read Timeout: 60 seconds
- Write Timeout: 5 seconds
- Heartbeat Interval: 30 seconds

## Testing

The handler includes comprehensive tests covering:
- JWT token validation
- Cross-origin request handling
- Message type validation
- Buffer configuration
- WebSocket upgrade process

## Integration

The handler is integrated with:
- **RealtimeService**: For GPT API communication
- **AudioProcessor**: For audio data validation and processing
- **JWT Middleware**: For authentication
- **Gin Router**: For HTTP/WebSocket routing

## Security Considerations

1. **Authentication**: All connections require valid JWT tokens
2. **Input Validation**: All client messages are validated
3. **Rate Limiting**: Connection timeouts prevent resource exhaustion
4. **Error Handling**: Sensitive information is not exposed in error messages
5. **Connection Limits**: Proper cleanup prevents connection leaks