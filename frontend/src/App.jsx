import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom'
import { FileText, LayoutDashboard, Users, Upload, FlaskConical } from 'lucide-react'
import Dashboard from './components/Dashboard'
import ContractDetail from './components/ContractDetail'
import TeamReview from './components/TeamReview'
import ExperimentDashboard from './components/ExperimentDashboard'

const NAV_ITEMS = [
  { path: '/', label: 'Dashboard', icon: LayoutDashboard },
  { path: '/team/Legal', label: 'Legal', icon: Users },
  { path: '/team/Technical/Ops', label: 'Technical', icon: Users },
  { path: '/team/Sales', label: 'Sales', icon: Users },
  { path: '/team/Marketing', label: 'Marketing', icon: Users },
  { path: '/experiments', label: 'Experiments', icon: FlaskConical },
]

function Sidebar() {
  const location = useLocation()
  return (
    <aside className="w-64 bg-white border-r border-gray-200 min-h-screen flex flex-col">
      <div className="p-6 border-b border-gray-200">
        <Link to="/" className="flex items-center gap-3">
          <div className="w-10 h-10 bg-snowflake-500 rounded-lg flex items-center justify-center">
            <FileText className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-gray-900">ContractAI</h1>
            <p className="text-xs text-gray-500">Powered by Snowflake</p>
          </div>
        </Link>
      </div>
      <nav className="flex-1 p-4 space-y-1">
        {NAV_ITEMS.map(item => {
          const Icon = item.icon
          const active = location.pathname === item.path
          return (
            <Link key={item.path} to={item.path}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active ? 'bg-snowflake-50 text-snowflake-700' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              }`}>
              <Icon className="w-5 h-5" />
              {item.label}
            </Link>
          )
        })}
      </nav>
      <div className="p-4 border-t border-gray-200">
        <p className="text-xs text-gray-400 text-center">Snowflake Cortex AI Demo</p>
      </div>
    </aside>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <div className="flex min-h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-auto">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/contract/:id" element={<ContractDetail />} />
            <Route path="/team/:team" element={<TeamReview />} />
            <Route path="/experiments" element={<ExperimentDashboard />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}
