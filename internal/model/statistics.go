package model

type LanguageStat struct {
	Language string `json:"language"`
	Count    int    `json:"count"`
}

type UserStat struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	Count    int    `json:"count"`
}

type TokenUsage struct {
	Date         string `json:"date"`
	InputTokens  int    `json:"input_tokens"`
	OutputTokens int    `json:"output_tokens"`
}

type StatisticsResponse struct {
	LanguageStats []*LanguageStat `json:"language_stats"`
	UserStats     []*UserStat     `json:"user_stats"`
	TokenUsage    []*TokenUsage   `json:"token_usage"`
}

