package service

import (
	"smart-glasses-backend/internal/model"
	"smart-glasses-backend/internal/repository"

	"github.com/google/uuid"
)

type UserService struct {
	userRepo *repository.UserRepository
}

func NewUserService(userRepo *repository.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

func (s *UserService) GetProfile(userID uuid.UUID) (*model.UserInfo, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return nil, err
	}

	return &model.UserInfo{
		ID:       user.ID,
		Username: user.Username,
		Email:    user.Email,
	}, nil
}

