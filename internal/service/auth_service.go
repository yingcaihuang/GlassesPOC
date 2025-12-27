package service

import (
	"context"
	"errors"
	"fmt"
	"smart-glasses-backend/internal/model"
	"smart-glasses-backend/internal/repository"
	"smart-glasses-backend/pkg/jwt"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	userRepo          *repository.UserRepository
	redisClient       *redis.Client
	secretKey         string
	accessTokenExpiry time.Duration
	refreshTokenExpiry time.Duration
}

func NewAuthService(userRepo *repository.UserRepository, redisClient *redis.Client, secretKey string, accessTokenExpiry, refreshTokenExpiry time.Duration) *AuthService {
	return &AuthService{
		userRepo:          userRepo,
		redisClient:     redisClient,
		secretKey:       secretKey,
		accessTokenExpiry:  accessTokenExpiry,
		refreshTokenExpiry: refreshTokenExpiry,
	}
}

func (s *AuthService) Register(req *model.RegisterRequest) (*model.AuthResponse, error) {
	// Check if email already exists
	exists, err := s.userRepo.ExistsByEmail(req.Email)
	if err != nil {
		return nil, fmt.Errorf("failed to check email: %w", err)
	}
	if exists {
		return nil, errors.New("email already exists")
	}

	// Check if username already exists
	exists, err = s.userRepo.ExistsByUsername(req.Username)
	if err != nil {
		return nil, fmt.Errorf("failed to check username: %w", err)
	}
	if exists {
		return nil, errors.New("username already exists")
	}

	// Validate password strength
	if err := validatePassword(req.Password); err != nil {
		return nil, err
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create user
	user := &model.User{
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Generate tokens
	return s.generateAuthResponse(user)
}

func (s *AuthService) Login(req *model.LoginRequest) (*model.AuthResponse, error) {
	// Check login attempts
	key := fmt.Sprintf("login_attempts:%s", req.Email)
	attempts, err := s.redisClient.Get(context.Background(), key).Int()
	if err != nil && err != redis.Nil {
		return nil, fmt.Errorf("failed to check login attempts: %w", err)
	}

	if attempts >= 5 {
		return nil, errors.New("too many login attempts, please try again later")
	}

	// Find user
	user, err := s.userRepo.FindByEmail(req.Email)
	if err != nil {
		s.incrementLoginAttempts(req.Email)
		return nil, errors.New("invalid email or password")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		s.incrementLoginAttempts(req.Email)
		return nil, errors.New("invalid email or password")
	}

	// Reset login attempts on successful login
	s.redisClient.Del(context.Background(), key)

	// Generate tokens
	return s.generateAuthResponse(user)
}

func (s *AuthService) Refresh(refreshToken string) (string, error) {
	// Validate refresh token
	claims, err := jwt.ValidateToken(refreshToken, s.secretKey)
	if err != nil {
		return "", errors.New("invalid refresh token")
	}

	// Check if refresh token exists in Redis
	key := fmt.Sprintf("refresh_token:%s", claims.ID)
	exists, err := s.redisClient.Exists(context.Background(), key).Result()
	if err != nil {
		return "", fmt.Errorf("failed to check refresh token: %w", err)
	}
	if exists == 0 {
		return "", errors.New("refresh token not found")
	}

	// Get user
	user, err := s.userRepo.FindByID(claims.UserID)
	if err != nil {
		return "", errors.New("user not found")
	}

	// Generate new access token
	newToken, err := jwt.GenerateToken(user.ID, user.Email, s.secretKey, s.accessTokenExpiry)
	if err != nil {
		return "", fmt.Errorf("failed to generate token: %w", err)
	}

	return newToken, nil
}

func (s *AuthService) generateAuthResponse(user *model.User) (*model.AuthResponse, error) {
	// Generate access token
	accessToken, err := jwt.GenerateToken(user.ID, user.Email, s.secretKey, s.accessTokenExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	// Generate refresh token
	refreshToken, err := jwt.GenerateToken(user.ID, user.Email, s.secretKey, s.refreshTokenExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Store refresh token in Redis
	claims, _ := jwt.ValidateToken(refreshToken, s.secretKey)
	key := fmt.Sprintf("refresh_token:%s", claims.ID)
	expiry := s.refreshTokenExpiry
	s.redisClient.Set(context.Background(), key, user.ID.String(), expiry)

	return &model.AuthResponse{
		Token:        accessToken,
		RefreshToken: refreshToken,
		User: model.UserInfo{
			ID:       user.ID,
			Username: user.Username,
			Email:    user.Email,
		},
		ExpiresIn: int(s.accessTokenExpiry.Seconds()),
	}, nil
}

func (s *AuthService) incrementLoginAttempts(email string) {
	key := fmt.Sprintf("login_attempts:%s", email)
	attempts, _ := s.redisClient.Incr(context.Background(), key).Result()
	if attempts == 1 {
		s.redisClient.Expire(context.Background(), key, 15*time.Minute)
	}
}

func validatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("password must be at least 8 characters long")
	}

	hasUpper := false
	hasLower := false
	hasDigit := false

	for _, char := range password {
		switch {
		case 'A' <= char && char <= 'Z':
			hasUpper = true
		case 'a' <= char && char <= 'z':
			hasLower = true
		case '0' <= char && char <= '9':
			hasDigit = true
		}
	}

	if !hasUpper || !hasLower || !hasDigit {
		return errors.New("password must contain uppercase, lowercase, and digit")
	}

	return nil
}

