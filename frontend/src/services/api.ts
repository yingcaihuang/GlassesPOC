import axios from 'axios'
import type { LoginCredentials, RegisterData, AuthResponse, User, TranslateRequest, TranslateResponse, TranslationHistoryResponse, StatisticsResponse } from '../types'

// Use relative URL in production (proxied by nginx), absolute URL in development
const API_BASE_URL = import.meta.env.VITE_API_URL || '/api/v1'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// 请求拦截器：添加token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器：处理401错误
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('refresh_token')
      localStorage.removeItem('user')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export const authApi = {
  login: async (credentials: LoginCredentials): Promise<AuthResponse> => {
    const response = await api.post('/auth/login', credentials)
    return response.data
  },

  register: async (data: RegisterData): Promise<AuthResponse> => {
    const response = await api.post('/auth/register', data)
    return response.data
  },

  refresh: async (refreshToken: string): Promise<{ token: string }> => {
    const response = await api.post('/auth/refresh', { refresh_token: refreshToken })
    return response.data
  },

  getProfile: async (token?: string): Promise<User> => {
    const headers = token ? { Authorization: `Bearer ${token}` } : {}
    const response = await api.get('/user/profile', { headers })
    return response.data
  },
}

export const translateApi = {
  translate: async (data: TranslateRequest): Promise<TranslateResponse> => {
    const response = await api.post('/translate/text', data)
    return response.data
  },

  getHistory: async (limit = 20, offset = 0): Promise<TranslationHistoryResponse> => {
    const response = await api.get('/translate/history', {
      params: { limit, offset },
    })
    return response.data
  },
}

export const statisticsApi = {
  getStatistics: async (): Promise<StatisticsResponse> => {
    const response = await api.get('/statistics')
    return response.data
  },
}

export default api

