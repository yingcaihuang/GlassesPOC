import { useAuth } from '../contexts/AuthContext'
import { User as UserIcon, Mail, Calendar } from 'lucide-react'

export default function Users() {
  const { user } = useAuth()

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">用户管理</h1>
        <p className="mt-2 text-gray-600">管理用户信息和设置</p>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex items-center space-x-4 mb-6">
          <div className="h-16 w-16 bg-primary-100 rounded-full flex items-center justify-center">
            <UserIcon className="h-8 w-8 text-primary-600" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-gray-900">{user?.username}</h2>
            <p className="text-gray-600">{user?.email}</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
            <UserIcon className="h-5 w-5 text-gray-400" />
            <div>
              <p className="text-sm font-medium text-gray-700">用户ID</p>
              <p className="text-sm text-gray-500">{user?.id}</p>
            </div>
          </div>

          <div className="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
            <Mail className="h-5 w-5 text-gray-400" />
            <div>
              <p className="text-sm font-medium text-gray-700">邮箱地址</p>
              <p className="text-sm text-gray-500">{user?.email}</p>
            </div>
          </div>

          <div className="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
            <Calendar className="h-5 w-5 text-gray-400" />
            <div>
              <p className="text-sm font-medium text-gray-700">账户状态</p>
              <p className="text-sm text-gray-500">活跃</p>
            </div>
          </div>
        </div>

        <div className="mt-6 pt-6 border-t border-gray-200">
          <p className="text-sm text-gray-600">
            注意：用户管理功能正在开发中。当前版本仅显示当前登录用户的信息。
          </p>
        </div>
      </div>
    </div>
  )
}

