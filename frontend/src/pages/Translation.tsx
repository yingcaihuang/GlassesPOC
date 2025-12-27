import { useState } from 'react'
import { translateApi } from '../services/api'
import { Languages, ArrowRight, Copy, Check } from 'lucide-react'
import type { TranslateResponse } from '../types'

const languages = [
  { code: 'en', name: '英语' },
  { code: 'zh', name: '中文' },
  { code: 'ja', name: '日语' },
  { code: 'ko', name: '韩语' },
  { code: 'fr', name: '法语' },
  { code: 'de', name: '德语' },
  { code: 'es', name: '西班牙语' },
  { code: 'ru', name: '俄语' },
]

export default function Translation() {
  const [sourceText, setSourceText] = useState('')
  const [sourceLanguage, setSourceLanguage] = useState('en')
  const [targetLanguage, setTargetLanguage] = useState('zh')
  const [result, setResult] = useState<TranslateResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState(false)

  const handleTranslate = async () => {
    if (!sourceText.trim()) {
      setError('请输入要翻译的文本')
      return
    }

    setError('')
    setLoading(true)
    setResult(null)

    try {
      const response = await translateApi.translate({
        text: sourceText,
        source_language: sourceLanguage,
        target_language: targetLanguage,
      })
      setResult(response)
    } catch (err: any) {
      setError(err.response?.data?.error || '翻译失败，请重试')
    } finally {
      setLoading(false)
    }
  }

  const handleCopy = () => {
    if (result?.translated_text) {
      navigator.clipboard.writeText(result.translated_text)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  const swapLanguages = () => {
    const temp = sourceLanguage
    setSourceLanguage(targetLanguage)
    setTargetLanguage(temp)
    if (result) {
      setResult(null)
    }
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">文本翻译</h1>
        <p className="mt-2 text-gray-600">使用AI进行多语言翻译</p>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        {/* Language Selection */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              源语言
            </label>
            <select
              value={sourceLanguage}
              onChange={(e) => setSourceLanguage(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent text-gray-900 bg-white"
            >
              {languages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-end justify-center">
            <button
              onClick={swapLanguages}
              className="p-2 text-gray-400 hover:text-primary-600 transition-colors"
              title="交换语言"
            >
              <ArrowRight className="h-6 w-6" />
            </button>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              目标语言
            </label>
            <select
              value={targetLanguage}
              onChange={(e) => setTargetLanguage(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent text-gray-900 bg-white"
            >
              {languages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Input */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            输入文本
          </label>
          <textarea
            value={sourceText}
            onChange={(e) => setSourceText(e.target.value)}
            rows={6}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none text-gray-900 bg-white"
            placeholder="请输入要翻译的文本..."
          />
          <div className="mt-2 flex justify-between items-center">
            <span className="text-sm text-gray-500">
              {sourceText.length} 字符
            </span>
            <button
              onClick={handleTranslate}
              disabled={loading || !sourceText.trim()}
              className="px-6 py-2 bg-primary-600 text-white rounded-lg font-medium hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                  翻译中...
                </>
              ) : (
                <>
                  <Languages className="mr-2 h-4 w-4" />
                  翻译
                </>
              )}
            </button>
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
            {error}
          </div>
        )}

        {/* Result */}
        {result && (
          <div className="mt-6">
            <div className="flex items-center justify-between mb-2">
              <label className="block text-sm font-medium text-gray-700">
                翻译结果
              </label>
              <button
                onClick={handleCopy}
                className="flex items-center text-sm text-gray-600 hover:text-primary-600 transition-colors"
              >
                {copied ? (
                  <>
                    <Check className="mr-1 h-4 w-4" />
                    已复制
                  </>
                ) : (
                  <>
                    <Copy className="mr-1 h-4 w-4" />
                    复制
                  </>
                )}
              </button>
            </div>
            <div className="px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg min-h-[100px]">
              <p className="text-gray-900 whitespace-pre-wrap">
                {result.translated_text}
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

