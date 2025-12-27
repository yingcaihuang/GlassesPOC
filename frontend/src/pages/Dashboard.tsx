import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { translateApi, statisticsApi } from '../services/api'
import { FileText, Clock, TrendingUp, Globe, Users, Zap } from 'lucide-react'
import { PieChart, Pie, Cell, ResponsiveContainer, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts'
import type { StatisticsResponse } from '../types'

const COLORS = ['#0ea5e9', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16']

export default function Dashboard() {
  const { user } = useAuth()
  const [stats, setStats] = useState({
    totalTranslations: 0,
    recentTranslations: 0,
  })
  const [statistics, setStatistics] = useState<StatisticsResponse | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Load basic stats
    translateApi.getHistory(100, 0)
      .then((response) => {
        const translations = response.data
        setStats({
          totalTranslations: translations.length,
          recentTranslations: translations.filter((t) => {
            const date = new Date(t.created_at)
            const now = new Date()
            const diffHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60)
            return diffHours < 24
          }).length,
        })
      })
      .catch(() => {
        // Ignore error
      })

    // Load statistics
    statisticsApi.getStatistics()
      .then((data) => {
        setStatistics(data)
      })
      .catch((err) => {
        console.error('Failed to load statistics:', err)
      })
      .finally(() => {
        setLoading(false)
      })
  }, [])

  const statCards = [
    {
      name: '总翻译数',
      value: stats.totalTranslations,
      icon: FileText,
      color: 'bg-blue-500',
    },
    {
      name: '今日翻译',
      value: stats.recentTranslations,
      icon: Clock,
      color: 'bg-green-500',
    },
    {
      name: '支持语言',
      value: '50+',
      icon: Globe,
      color: 'bg-purple-500',
    },
    {
      name: '用户状态',
      value: '活跃',
      icon: TrendingUp,
      color: 'bg-orange-500',
    },
  ]

  // Prepare language data for pie chart
  const languageData = statistics?.language_stats?.map((stat) => ({
    name: getLanguageName(stat.language),
    value: stat.count,
  })) || []

  // Prepare user data for chart
  const userData = statistics?.user_stats?.map((stat) => ({
    name: stat.username,
    value: stat.count,
  })) || []

  // Prepare token usage data for line chart
  const tokenData = statistics?.token_usage?.map((usage) => ({
    date: usage.date,
    '输入Token': usage.input_tokens,
    '输出Token': usage.output_tokens,
  })) || []

  function getLanguageName(code: string): string {
    const langMap: Record<string, string> = {
      'en': '英语',
      'zh': '中文',
      'ja': '日语',
      'ko': '韩语',
      'fr': '法语',
      'de': '德语',
      'es': '西班牙语',
      'ru': '俄语',
    }
    return langMap[code] || code.toUpperCase()
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">仪表盘</h1>
        <p className="mt-2 text-gray-600">欢迎回来，{user?.username}！</p>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 mb-8">
        {statCards.map((stat) => {
          const Icon = stat.icon
          return (
            <div
              key={stat.name}
              className="bg-white rounded-xl shadow-sm border border-gray-200 p-6"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">{stat.name}</p>
                  <p className="mt-2 text-3xl font-bold text-gray-900">{stat.value}</p>
                </div>
                <div className={`${stat.color} p-3 rounded-lg`}>
                  <Icon className="h-6 w-6 text-white" />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Language Statistics Pie Chart */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center mb-4">
            <Globe className="h-5 w-5 text-primary-600 mr-2" />
            <h2 className="text-xl font-bold text-gray-900">翻译语种分布</h2>
          </div>
          {loading ? (
            <div className="flex justify-center items-center h-64">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : languageData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={languageData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {languageData.map((_entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex justify-center items-center h-64 text-gray-500">
              暂无数据
            </div>
          )}
        </div>

        {/* User Statistics */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center mb-4">
            <Users className="h-5 w-5 text-primary-600 mr-2" />
            <h2 className="text-xl font-bold text-gray-900">用户翻译统计</h2>
          </div>
          {loading ? (
            <div className="flex justify-center items-center h-64">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : userData.length > 0 ? (
            <div className="space-y-3">
              {userData.slice(0, 10).map((user: { name: string; value: number }, index: number) => (
                <div key={user.name} className="flex items-center justify-between">
                  <div className="flex items-center">
                    <div className={`w-3 h-3 rounded-full mr-3`} style={{ backgroundColor: COLORS[index % COLORS.length] }}></div>
                    <span className="text-sm font-medium text-gray-700">{user.name}</span>
                  </div>
                  <span className="text-sm font-bold text-gray-900">{user.value}</span>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex justify-center items-center h-64 text-gray-500">
              暂无数据
            </div>
          )}
        </div>
      </div>

      {/* Token Usage Line Chart */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex items-center mb-4">
          <Zap className="h-5 w-5 text-primary-600 mr-2" />
          <h2 className="text-xl font-bold text-gray-900">OpenAI Token 使用统计</h2>
        </div>
        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
          </div>
        ) : tokenData.length > 0 ? (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={tokenData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="date" 
                tick={{ fontSize: 12 }}
                angle={-45}
                textAnchor="end"
                height={80}
              />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip />
              <Legend />
              <Line 
                type="monotone" 
                dataKey="输入Token" 
                stroke="#0ea5e9" 
                strokeWidth={2}
                dot={{ r: 4 }}
                activeDot={{ r: 6 }}
              />
              <Line 
                type="monotone" 
                dataKey="输出Token" 
                stroke="#10b981" 
                strokeWidth={2}
                dot={{ r: 4 }}
                activeDot={{ r: 6 }}
              />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div className="flex justify-center items-center h-64 text-gray-500">
            暂无Token使用数据
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="mt-8 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-xl font-bold text-gray-900 mb-4">快速开始</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <a
            href="/translation"
            className="p-4 border border-gray-200 rounded-lg hover:border-primary-500 hover:bg-primary-50 transition-colors"
          >
            <h3 className="font-semibold text-gray-900 mb-2">开始翻译</h3>
            <p className="text-sm text-gray-600">使用AI翻译文本内容</p>
          </a>
          <a
            href="/history"
            className="p-4 border border-gray-200 rounded-lg hover:border-primary-500 hover:bg-primary-50 transition-colors"
          >
            <h3 className="font-semibold text-gray-900 mb-2">查看历史</h3>
            <p className="text-sm text-gray-600">浏览所有翻译记录</p>
          </a>
        </div>
      </div>
    </div>
  )
}
