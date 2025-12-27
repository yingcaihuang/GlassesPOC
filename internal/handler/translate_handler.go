package handler

import (
	"net/http"
	"smart-glasses-backend/internal/model"
	"smart-glasses-backend/internal/service"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/google/uuid"
)

type TranslateHandler struct {
	translateService *service.TranslateService
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in development
	},
}

func NewTranslateHandler(translateService *service.TranslateService) *TranslateHandler {
	return &TranslateHandler{translateService: translateService}
}

func (h *TranslateHandler) TranslateText(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req model.TranslateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userUUID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	resp, err := h.translateService.TranslateText(userUUID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *TranslateHandler) GetHistory(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	userUUID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	history, err := h.translateService.GetHistory(userUUID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": history})
}

func (h *TranslateHandler) TranslateStream(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	userUUID, err := uuid.Parse(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to upgrade connection"})
		return
	}
	defer conn.Close()

	var fullTranslatedText string
	var currentText string
	var sourceLanguage string
	var targetLanguage string

	for {
		var msg model.WebSocketMessage
		if err := conn.ReadJSON(&msg); err != nil {
			conn.WriteJSON(model.WebSocketMessage{
				Type:  "error",
				Error: "failed to read message",
			})
			break
		}

		switch msg.Type {
		case "translate":
			if msg.Text == "" || msg.SourceLanguage == "" || msg.TargetLanguage == "" {
				conn.WriteJSON(model.WebSocketMessage{
					Type:  "error",
					Error: "missing required fields",
				})
				continue
			}

			currentText = msg.Text
			sourceLanguage = msg.SourceLanguage
			targetLanguage = msg.TargetLanguage
			fullTranslatedText = ""

			// Stream translation
			err := h.translateService.TranslateStream(userUUID, msg.Text, msg.SourceLanguage, msg.TargetLanguage, func(chunk string) error {
				fullTranslatedText += chunk
				return conn.WriteJSON(model.WebSocketMessage{
					Type:           "translation_chunk",
					TranslatedText: chunk,
					IsComplete:     false,
				})
			})

			if err != nil {
				conn.WriteJSON(model.WebSocketMessage{
					Type:  "error",
					Error: err.Error(),
				})
				continue
			}

			// Send completion message
			conn.WriteJSON(model.WebSocketMessage{
				Type:           "translation_complete",
				TranslatedText: fullTranslatedText,
				IsComplete:     true,
			})

			// Save to history (async, don't block)
			go func() {
				translation := &model.Translation{
					UserID:         userUUID,
					SourceText:     currentText,
					TranslatedText: fullTranslatedText,
					SourceLanguage: sourceLanguage,
					TargetLanguage: targetLanguage,
				}
				_ = h.translateService.SaveTranslation(translation)
			}()

		default:
			conn.WriteJSON(model.WebSocketMessage{
				Type:  "error",
				Error: "unknown message type",
			})
		}
	}
}

