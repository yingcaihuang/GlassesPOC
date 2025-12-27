package repository

import (
	"database/sql"
	"errors"
	"smart-glasses-backend/internal/model"
	"time"

	"github.com/google/uuid"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user *model.User) error {
	query := `INSERT INTO users (id, username, email, password_hash, created_at, updated_at)
			  VALUES ($1, $2, $3, $4, $5, $6)`
	
	user.ID = uuid.New()
	now := time.Now()
	if !user.CreatedAt.IsZero() {
		now = user.CreatedAt
	}
	
	_, err := r.db.Exec(query, user.ID, user.Username, user.Email, user.PasswordHash, now, now)
	return err
}

func (r *UserRepository) FindByEmail(email string) (*model.User, error) {
	user := &model.User{}
	query := `SELECT id, username, email, password_hash, created_at, updated_at
			  FROM users WHERE email = $1`
	
	err := r.db.QueryRow(query, email).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	
	if err == sql.ErrNoRows {
		return nil, errors.New("user not found")
	}
	if err != nil {
		return nil, err
	}
	
	return user, nil
}

func (r *UserRepository) FindByID(id uuid.UUID) (*model.User, error) {
	user := &model.User{}
	query := `SELECT id, username, email, password_hash, created_at, updated_at
			  FROM users WHERE id = $1`
	
	err := r.db.QueryRow(query, id).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	
	if err == sql.ErrNoRows {
		return nil, errors.New("user not found")
	}
	if err != nil {
		return nil, err
	}
	
	return user, nil
}

func (r *UserRepository) ExistsByEmail(email string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`
	err := r.db.QueryRow(query, email).Scan(&exists)
	return exists, err
}

func (r *UserRepository) ExistsByUsername(username string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)`
	err := r.db.QueryRow(query, username).Scan(&exists)
	return exists, err
}

