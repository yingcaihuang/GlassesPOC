package service

import (
	"smart-glasses-backend/internal/model"
	"smart-glasses-backend/internal/repository"
	"smart-glasses-backend/pkg/azure"

	"github.com/google/uuid"
)

type TranslateService struct {
	azureClient   *azure.OpenAIClient
	translateRepo *repository.TranslateRepository
	tokenRepo     *repository.TokenRepository
}

func NewTranslateService(azureClient *azure.OpenAIClient, translateRepo *repository.TranslateRepository, tokenRepo *repository.TokenRepository) *TranslateService {
	return &TranslateService{
		azureClient:   azureClient,
		translateRepo: translateRepo,
		tokenRepo:     tokenRepo,
	}
}

func (s *TranslateService) TranslateText(userID uuid.UUID, req *model.TranslateRequest) (*model.TranslateResponse, error) {
	// Call Azure OpenAI
	translatedText, inputTokens, outputTokens, err := s.azureClient.Translate(req.Text, req.SourceLanguage, req.TargetLanguage)
	if err != nil {
		return nil, err
	}

	// Save to history
	translation := &model.Translation{
		UserID:         userID,
		SourceText:     req.Text,
		TranslatedText: translatedText,
		SourceLanguage: req.SourceLanguage,
		TargetLanguage: req.TargetLanguage,
	}
	if err := s.translateRepo.Create(translation); err != nil {
		// Log error but don't fail the request
		_ = err
	}

	// Save token usage (async, don't block)
	go func() {
		if inputTokens > 0 || outputTokens > 0 {
			_ = s.tokenRepo.Create(userID, inputTokens, outputTokens)
		}
	}()

	return &model.TranslateResponse{
		TranslatedText: translatedText,
		SourceLanguage: req.SourceLanguage,
		TargetLanguage: req.TargetLanguage,
	}, nil
}

func (s *TranslateService) TranslateStream(userID uuid.UUID, text, sourceLanguage, targetLanguage string, callback func(string) error) error {
	return s.azureClient.TranslateStream(text, sourceLanguage, targetLanguage, callback)
}

func (s *TranslateService) GetHistory(userID uuid.UUID, limit, offset int) ([]*model.TranslationHistoryResponse, error) {
	translations, err := s.translateRepo.GetHistory(userID, limit, offset)
	if err != nil {
		return nil, err
	}

	result := make([]*model.TranslationHistoryResponse, len(translations))
	for i, t := range translations {
		result[i] = &model.TranslationHistoryResponse{
			ID:             t.ID,
			SourceText:     t.SourceText,
			TranslatedText: t.TranslatedText,
			SourceLanguage: t.SourceLanguage,
			TargetLanguage: t.TargetLanguage,
			CreatedAt:      t.CreatedAt,
		}
	}

	return result, nil
}

func (s *TranslateService) SaveTranslation(translation *model.Translation) error {
	return s.translateRepo.Create(translation)
}
