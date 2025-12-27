package repository

import (
	"database/sql"
	"smart-glasses-backend/internal/model"
	"time"

	"github.com/google/uuid"
)

type TranslateRepository struct {
	db *sql.DB
}

func NewTranslateRepository(db *sql.DB) *TranslateRepository {
	return &TranslateRepository{db: db}
}

func (r *TranslateRepository) Create(translation *model.Translation) error {
	query := `INSERT INTO translation_history (id, user_id, source_text, translated_text, source_language, target_language, created_at)
			  VALUES ($1, $2, $3, $4, $5, $6, $7)`
	
	translation.ID = uuid.New()
	now := time.Now()
	if !translation.CreatedAt.IsZero() {
		now = translation.CreatedAt
	}
	
	_, err := r.db.Exec(query,
		translation.ID,
		translation.UserID,
		translation.SourceText,
		translation.TranslatedText,
		translation.SourceLanguage,
		translation.TargetLanguage,
		now,
	)
	return err
}

func (r *TranslateRepository) GetHistory(userID uuid.UUID, limit, offset int) ([]*model.Translation, error) {
	query := `SELECT id, user_id, source_text, translated_text, source_language, target_language, created_at
			  FROM translation_history
			  WHERE user_id = $1
			  ORDER BY created_at DESC
			  LIMIT $2 OFFSET $3`
	
	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var translations []*model.Translation
	for rows.Next() {
		t := &model.Translation{}
		err := rows.Scan(
			&t.ID,
			&t.UserID,
			&t.SourceText,
			&t.TranslatedText,
			&t.SourceLanguage,
			&t.TargetLanguage,
			&t.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		translations = append(translations, t)
	}
	
	return translations, rows.Err()
}

func (r *TranslateRepository) GetLanguageStats(userID uuid.UUID) ([]*model.LanguageStat, error) {
	query := `SELECT target_language, COUNT(*) as count
			  FROM translation_history
			  WHERE user_id = $1
			  GROUP BY target_language
			  ORDER BY count DESC`
	
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var stats []*model.LanguageStat
	for rows.Next() {
		s := &model.LanguageStat{}
		err := rows.Scan(&s.Language, &s.Count)
		if err != nil {
			return nil, err
		}
		stats = append(stats, s)
	}
	
	return stats, rows.Err()
}

func (r *TranslateRepository) GetAllLanguageStats() ([]*model.LanguageStat, error) {
	query := `SELECT target_language, COUNT(*) as count
			  FROM translation_history
			  GROUP BY target_language
			  ORDER BY count DESC`
	
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var stats []*model.LanguageStat
	for rows.Next() {
		s := &model.LanguageStat{}
		err := rows.Scan(&s.Language, &s.Count)
		if err != nil {
			return nil, err
		}
		stats = append(stats, s)
	}
	
	return stats, rows.Err()
}

func (r *TranslateRepository) GetUserStats() ([]*model.UserStat, error) {
	query := `SELECT u.id, u.username, COUNT(th.id) as count
			  FROM users u
			  LEFT JOIN translation_history th ON u.id = th.user_id
			  GROUP BY u.id, u.username
			  ORDER BY count DESC
			  LIMIT 10`
	
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var stats []*model.UserStat
	for rows.Next() {
		s := &model.UserStat{}
		err := rows.Scan(&s.UserID, &s.Username, &s.Count)
		if err != nil {
			return nil, err
		}
		stats = append(stats, s)
	}
	
	return stats, rows.Err()
}

