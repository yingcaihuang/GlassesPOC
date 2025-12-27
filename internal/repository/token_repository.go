package repository

import (
	"database/sql"
	"smart-glasses-backend/internal/model"
	"time"

	"github.com/google/uuid"
)

type TokenRepository struct {
	db *sql.DB
}

func NewTokenRepository(db *sql.DB) *TokenRepository {
	return &TokenRepository{db: db}
}

func (r *TokenRepository) Create(userID uuid.UUID, inputTokens, outputTokens int) error {
	query := `INSERT INTO token_usage (id, user_id, input_tokens, output_tokens, created_at)
			  VALUES ($1, $2, $3, $4, $5)`
	
	_, err := r.db.Exec(query, uuid.New(), userID, inputTokens, outputTokens, time.Now())
	return err
}

func (r *TokenRepository) GetTokenUsage(userID uuid.UUID, days int) ([]*model.TokenUsage, error) {
	query := `SELECT 
				DATE(created_at) as date,
				SUM(input_tokens) as input_tokens,
				SUM(output_tokens) as output_tokens
			  FROM token_usage
			  WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '1 day' * $2
			  GROUP BY DATE(created_at)
			  ORDER BY date ASC`
	
	rows, err := r.db.Query(query, userID, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var usage []*model.TokenUsage
	for rows.Next() {
		u := &model.TokenUsage{}
		var date time.Time
		err := rows.Scan(&date, &u.InputTokens, &u.OutputTokens)
		if err != nil {
			return nil, err
		}
		u.Date = date.Format("2006-01-02")
		usage = append(usage, u)
	}
	
	return usage, rows.Err()
}

func (r *TokenRepository) GetAllTokenUsage(days int) ([]*model.TokenUsage, error) {
	query := `SELECT 
				DATE(created_at) as date,
				SUM(input_tokens) as input_tokens,
				SUM(output_tokens) as output_tokens
			  FROM token_usage
			  WHERE created_at >= NOW() - INTERVAL '1 day' * $1
			  GROUP BY DATE(created_at)
			  ORDER BY date ASC`
	
	rows, err := r.db.Query(query, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var usage []*model.TokenUsage
	for rows.Next() {
		u := &model.TokenUsage{}
		var date time.Time
		err := rows.Scan(&date, &u.InputTokens, &u.OutputTokens)
		if err != nil {
			return nil, err
		}
		u.Date = date.Format("2006-01-02")
		usage = append(usage, u)
	}
	
	return usage, rows.Err()
}

