import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { FileText, AlertTriangle, CheckCircle, Search, Filter } from 'lucide-react'
import { RiskBadge, TeamBadge } from './Badges'

export default function Dashboard() {
  const [contracts, setContracts] = useState([])
  const [stats, setStats] = useState(null)
  const [search, setSearch] = useState('')
  const [riskFilter, setRiskFilter] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadData()
  }, [search, riskFilter])

  async function loadData() {
    setLoading(true)
    try {
      const params = new URLSearchParams()
      if (search) params.set('search', search)
      if (riskFilter) params.set('risk', riskFilter)

      const [contractsRes, statsRes] = await Promise.all([
        fetch(`/api/contracts?${params}`),
        fetch('/api/dashboard/stats')
      ])
      setContracts(await contractsRes.json())
      setStats(await statsRes.json())
    } catch (e) {
      console.error('Failed to load data:', e)
    }
    setLoading(false)
  }

  const statCards = stats ? [
    { label: 'Total Contracts', value: stats.total_contracts, icon: FileText, color: 'text-snowflake-500', bg: 'bg-snowflake-50' },
    { label: 'High Risk', value: stats.risk_distribution?.High || 0, icon: AlertTriangle, color: 'text-red-500', bg: 'bg-red-50' },
    { label: 'Medium Risk', value: stats.risk_distribution?.Medium || 0, icon: AlertTriangle, color: 'text-amber-500', bg: 'bg-amber-50' },
    { label: 'Low Risk', value: stats.risk_distribution?.Low || 0, icon: CheckCircle, color: 'text-green-500', bg: 'bg-green-50' },
  ] : []

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Contract Review Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">AI-powered contract analysis with team-based review routing</p>
      </div>

      {stats && (
        <div className="grid grid-cols-4 gap-4 mb-8">
          {statCards.map(card => (
            <div key={card.label} className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{card.label}</p>
                  <p className="text-3xl font-bold mt-1 text-gray-900">{card.value}</p>
                </div>
                <div className={`w-12 h-12 ${card.bg} rounded-lg flex items-center justify-center`}>
                  <card.icon className={`w-6 h-6 ${card.color}`} />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-4 border-b border-gray-200 flex items-center gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input type="text" placeholder="Search contracts..." value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-snowflake-500 focus:border-transparent" />
          </div>
          <div className="flex items-center gap-2">
            <Filter className="w-4 h-4 text-gray-400" />
            {['', 'High', 'Medium', 'Low'].map(r => (
              <button key={r} onClick={() => setRiskFilter(r)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                  riskFilter === r ? 'bg-snowflake-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}>
                {r || 'All'}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="p-12 text-center text-gray-400">
            <div className="animate-spin w-8 h-8 border-2 border-snowflake-500 border-t-transparent rounded-full mx-auto mb-3" />
            Loading contracts...
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200 bg-gray-50">
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Contract</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Parties</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Risk</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Clauses</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">High Risk</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {contracts.map(c => (
                  <tr key={c.contract_id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-4 py-3">
                      <Link to={`/contract/${c.contract_id}`} className="text-sm font-medium text-snowflake-600 hover:text-snowflake-700">
                        {c.contract_name || 'Unnamed'}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600">{c.contract_type}</td>
                    <td className="px-4 py-3 text-sm text-gray-500 max-w-xs truncate">{c.parties}</td>
                    <td className="px-4 py-3"><RiskBadge level={c.overall_risk} /></td>
                    <td className="px-4 py-3 text-sm text-gray-600">{c.clause_count}</td>
                    <td className="px-4 py-3">
                      {c.high_risk_count > 0 ? (
                        <span className="inline-flex items-center gap-1 text-sm text-red-600 font-medium">
                          <AlertTriangle className="w-3.5 h-3.5" /> {c.high_risk_count}
                        </span>
                      ) : (
                        <span className="text-sm text-gray-400">0</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {contracts.length === 0 && (
              <div className="p-12 text-center text-gray-400">No contracts found</div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
