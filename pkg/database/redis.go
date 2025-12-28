package database

import (
	"context"

	"github.com/redis/go-redis/v9"
)

func NewRedis(addr, password string) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       0,
	})

	ctx := context.Background()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, err
	}

	return client, nil
}

