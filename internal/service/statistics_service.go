package service

import (
	"smart-glasses-backend/internal/model"
	"smart-glasses-backend/internal/repository"

	"github.com/google/uuid"
)

type StatisticsService struct {
	translateRepo *repository.TranslateRepository
	tokenRepo     *repository.TokenRepository
}

func NewStatisticsService(translateRepo *repository.TranslateRepository, tokenRepo *repository.TokenRepository) *StatisticsService {
	return &StatisticsService{
		translateRepo: translateRepo,
		tokenRepo:     tokenRepo,
	}
}

func (s *StatisticsService) GetStatistics(userID uuid.UUID, isAdmin bool) (*model.StatisticsResponse, error) {
	var languageStats []*model.LanguageStat
	var userStats []*model.UserStat
	var tokenUsage []*model.TokenUsage

	if isAdmin {
		// Admin can see all stats
		languageStats, _ = s.translateRepo.GetAllLanguageStats()
		userStats, _ = s.translateRepo.GetUserStats()
		tokenUsage, _ = s.tokenRepo.GetAllTokenUsage(30) // Last 30 days
	} else {
		// Regular user sees only their stats
		languageStats, _ = s.translateRepo.GetLanguageStats(userID)
		tokenUsage, _ = s.tokenRepo.GetTokenUsage(userID, 30) // Last 30 days
	}

	return &model.StatisticsResponse{
		LanguageStats: languageStats,
		UserStats:     userStats,
		TokenUsage:    tokenUsage,
	}, nil
}
