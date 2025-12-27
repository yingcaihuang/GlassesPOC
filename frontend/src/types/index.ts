export interface User {
  id: string
  username: string
  email: string
}

export interface LoginCredentials {
  email: string
  password: string
}

export interface RegisterData {
  username: string
  email: string
  password: string
}

export interface AuthResponse {
  token: string
  refresh_token: string
  user: User
  expires_in: number
}

export interface TranslateRequest {
  text: string
  source_language: string
  target_language: string
}

export interface TranslateResponse {
  translated_text: string
  source_language: string
  target_language: string
}

export interface TranslationHistory {
  id: string
  source_text: string
  translated_text: string
  source_language: string
  target_language: string
  created_at: string
}

export interface TranslationHistoryResponse {
  data: TranslationHistory[]
}

export interface LanguageStat {
  language: string
  count: number
}

export interface UserStat {
  user_id: string
  username: string
  count: number
}

export interface TokenUsage {
  date: string
  input_tokens: number
  output_tokens: number
}

export interface StatisticsResponse {
  language_stats: LanguageStat[]
  user_stats: UserStat[]
  token_usage: TokenUsage[]
}
