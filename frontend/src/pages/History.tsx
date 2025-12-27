import { useState, useEffect } from 'react'
import { translateApi } from '../services/api'
import { Search, ChevronLeft, ChevronRight } from 'lucide-react'
import type { TranslationHistory } from '../types'
import { format } from 'date-fns'

export default function History() {
  const [history, setHistory] = useState<TranslationHistory[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const [totalCount, setTotalCount] = useState(0)
  const itemsPerPage = 20

  useEffect(() => {
    loadHistory()
  }, [currentPage])

  const loadHistory = async () => {
    setLoading(true)
    try {
      const offset = (currentPage - 1) * itemsPerPage
      const response = await translateApi.getHistory(itemsPerPage, offset)
      setHistory(response.data)
      setTotalCount(response.data.length)
    } catch (error) {
      console.error('Failed to load history:', error)
    } finally {
      setLoading(false)
    }
  }

  const filteredHistory = history.filter((item) =>
    item.source_text.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.translated_text.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const totalPages = Math.ceil(totalCount / itemsPerPage)

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">翻译历史</h1>
        <p className="mt-2 text-gray-600">查看所有翻译记录</p>
      </div>

      {/* Search */}
      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="搜索翻译历史..."
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent text-gray-900 bg-white"
          />
        </div>
      </div>

      {/* History List */}
      {loading ? (
        <div className="flex justify-center items-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      ) : filteredHistory.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-xl border border-gray-200">
          <p className="text-gray-500">暂无翻译历史</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredHistory.map((item) => (
            <div
              key={item.id}
              className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-2">
                  <span className="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded">
                    {item.source_language.toUpperCase()}
                  </span>
                  <span className="text-gray-400">→</span>
                  <span className="px-2 py-1 text-xs font-medium bg-green-100 text-green-800 rounded">
                    {item.target_language.toUpperCase()}
                  </span>
                </div>
                <span className="text-sm text-gray-500">
                  {format(new Date(item.created_at), 'yyyy-MM-dd HH:mm')}
                </span>
              </div>
              <div className="space-y-3">
                <div>
                  <p className="text-sm font-medium text-gray-600 mb-1">原文</p>
                  <p className="text-gray-900">{item.source_text}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-600 mb-1">译文</p>
                  <p className="text-gray-900">{item.translated_text}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-6 flex items-center justify-between">
          <div className="text-sm text-gray-700">
            显示第 {(currentPage - 1) * itemsPerPage + 1} - {Math.min(currentPage * itemsPerPage, totalCount)} 条，共 {totalCount} 条
          </div>
          <div className="flex space-x-2">
            <button
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1}
              className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors flex items-center"
            >
              <ChevronLeft className="h-4 w-4 mr-1" />
              上一页
            </button>
            <button
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
              className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors flex items-center"
            >
              下一页
              <ChevronRight className="h-4 w-4 ml-1" />
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

