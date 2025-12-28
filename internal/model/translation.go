package model

import (
	"time"

	"github.com/google/uuid"
)

type Translation struct {
	ID              uuid.UUID `json:"id" db:"id"`
	UserID          uuid.UUID `json:"user_id" db:"user_id"`
	SourceText      string    `json:"source_text" db:"source_text"`
	TranslatedText  string    `json:"translated_text" db:"translated_text"`
	SourceLanguage  string    `json:"source_language" db:"source_language"`
	TargetLanguage  string    `json:"target_language" db:"target_language"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
}

type TranslateRequest struct {
	Text          string `json:"text" binding:"required"`
	SourceLanguage string `json:"source_language" binding:"required"`
	TargetLanguage string `json:"target_language" binding:"required"`
}

type TranslateResponse struct {
	TranslatedText string `json:"translated_text"`
	SourceLanguage string `json:"source_language"`
	TargetLanguage string `json:"target_language"`
}

type TranslationHistoryResponse struct {
	ID              uuid.UUID `json:"id"`
	SourceText      string    `json:"source_text"`
	TranslatedText  string    `json:"translated_text"`
	SourceLanguage  string    `json:"source_language"`
	TargetLanguage  string    `json:"target_language"`
	CreatedAt       time.Time `json:"created_at"`
}

type WebSocketMessage struct {
	Type           string `json:"type"`
	Text           string `json:"text,omitempty"`
	SourceLanguage string `json:"source_language,omitempty"`
	TargetLanguage string `json:"target_language,omitempty"`
	TranslatedText string `json:"translated_text,omitempty"`
	IsComplete     bool   `json:"is_complete,omitempty"`
	Error          string `json:"error,omitempty"`
}

