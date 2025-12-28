package handler

import (
	"net/http"
	"smart-glasses-backend/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type StatisticsHandler struct {
	statisticsService *service.StatisticsService
}

func NewStatisticsHandler(statisticsService *service.StatisticsService) *StatisticsHandler {
	return &StatisticsHandler{statisticsService: statisticsService}
}

func (h *StatisticsHandler) GetStatistics(c *gin.Context) {
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

	// For now, treat all users as non-admin
	// In the future, you can check user role from database
	isAdmin := false

	stats, err := h.statisticsService.GetStatistics(userUUID, isAdmin)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

