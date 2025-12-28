import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Translation from './pages/Translation'
import History from './pages/History'
import Users from './pages/Users'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Navigate to="/dashboard" replace />} />
            <Route path="dashboard" element={<Dashboard />} />
            <Route path="translation" element={<Translation />} />
            <Route path="history" element={<History />} />
            <Route path="users" element={<Users />} />
          </Route>
        </Routes>
      </Router>
    </AuthProvider>
  )
}

export default App

