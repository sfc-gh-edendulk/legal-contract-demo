import { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, FileText, CheckCircle, XCircle, Flag, AlertTriangle } from 'lucide-react'
import { RiskBadge, TeamBadge, StatusBadge } from './Badges'

export default function TeamReview() {
  const { team } = useParams()
  const decodedTeam = decodeURIComponent(team)
  const [clauses, setClauses] = useState([])
  const [loading, setLoading] = useState(true)
  const [statusFilter, setStatusFilter] = useState('')

  useEffect(() => {
    loadClauses()
  }, [team])

  async function loadClauses() {
    setLoading(true)
    try {
      const res = await fetch(`/api/teams/${encodeURIComponent(decodedTeam)}/review`)
      setClauses(await res.json())
    } catch (e) {
      console.error('Failed to load team review:', e)
    }
    setLoading(false)
  }

  async function updateClauseStatus(contractId, clauseId, status) {
    try {
      await fetch(`/api/contracts/${contractId}/clauses/${clauseId}/review`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status })
      })
      setClauses(prev => prev.map(c => c.clause_id === clauseId ? { ...c, review_status: status } : c))
    } catch (e) {
      console.error('Failed to update:', e)
    }
  }

  const filtered = statusFilter ? clauses.filter(c => c.review_status === statusFilter) : clauses

  const stats = {
    total: clauses.length,
    pending: clauses.filter(c => c.review_status === 'pending').length,
    approved: clauses.filter(c => c.review_status === 'approved').length,
    flagged: clauses.filter(c => c.review_status === 'flagged').length,
    rejected: clauses.filter(c => c.review_status === 'rejected').length,
    highRisk: clauses.filter(c => c.risk_level === 'High').length,
  }

  const teamColors = {
    'Legal': 'from-blue-500 to-blue-600',
    'Technical/Ops': 'from-purple-500 to-purple-600',
    'Sales': 'from-emerald-500 to-emerald-600',
    'Marketing': 'from-orange-500 to-orange-600',
  }

  return (
    <div className="p-8">
      <div className="flex items-center gap-4 mb-6">
        <Link to="/" className="text-gray-400 hover:text-gray-600"><ArrowLeft className="w-5 h-5" /></Link>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{decodedTeam} Review Queue</h1>
          <p className="text-sm text-gray-500">Clauses assigned to {decodedTeam} for review</p>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className={`bg-gradient-to-r ${teamColors[decodedTeam] || 'from-gray-500 to-gray-600'} rounded-xl p-5 text-white`}>
          <p className="text-sm opacity-80">Total Clauses</p>
          <p className="text-3xl font-bold">{stats.total}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <p className="text-sm text-gray-500">Pending Review</p>
          <p className="text-3xl font-bold text-amber-500">{stats.pending}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <p className="text-sm text-gray-500">Approved</p>
          <p className="text-3xl font-bold text-green-500">{stats.approved}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <p className="text-sm text-gray-500">High Risk</p>
          <p className="text-3xl font-bold text-red-500">{stats.highRisk}</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-4 border-b border-gray-200 flex gap-2">
          {[['', 'All'], ['pending', 'Pending'], ['approved', 'Approved'], ['flagged', 'To Modify'], ['rejected', 'Problematic']].map(([s, label]) => (
            <button key={s} onClick={() => setStatusFilter(s)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                statusFilter === s ? 'bg-snowflake-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}>
              {label} ({s ? clauses.filter(c => c.review_status === s).length : clauses.length})
            </button>
          ))}
        </div>

        {loading ? (
          <div className="p-12 text-center">
            <div className="animate-spin w-8 h-8 border-2 border-snowflake-500 border-t-transparent rounded-full mx-auto" />
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {filtered.map(clause => (
              <div key={clause.clause_id} className="p-4 hover:bg-gray-50 transition-colors">
                <div className="flex items-start justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Link to={`/contract/${clause.contract_id}`}
                      className="text-sm font-medium text-snowflake-600 hover:text-snowflake-700 flex items-center gap-1">
                      <FileText className="w-3.5 h-3.5" /> {clause.contract_name}
                    </Link>
                    <span className="text-xs text-gray-400">·</span>
                    <span className="text-xs text-gray-500">{clause.contract_type}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <RiskBadge level={clause.risk_level} />
                    <StatusBadge status={clause.review_status} />
                  </div>
                </div>
                <p className="text-sm font-medium text-gray-800 mb-1">{clause.clause_type}</p>
                <p className="text-sm text-gray-600 mb-2 line-clamp-2">{clause.clause_text}</p>
                <div className="flex items-center justify-between">
                  <p className="text-xs text-gray-500 italic">{clause.risk_explanation}</p>
                  <div className="flex items-center gap-1 ml-4">
                    {!['approved','flagged','rejected'].includes(clause.review_status) ? (
                      <>
                        <button onClick={() => updateClauseStatus(clause.contract_id, clause.clause_id, 'approved')}
                          title="Approve"
                          className="p-1 rounded hover:bg-green-100 text-green-600 hover:text-green-700 transition-colors">
                          <CheckCircle className="w-4 h-4" />
                        </button>
                        <button onClick={() => updateClauseStatus(clause.contract_id, clause.clause_id, 'flagged')}
                          title="Flag for Modification"
                          className="p-1 rounded hover:bg-amber-100 text-amber-600 hover:text-amber-700 transition-colors">
                          <Flag className="w-4 h-4" />
                        </button>
                        <button onClick={() => updateClauseStatus(clause.contract_id, clause.clause_id, 'rejected')}
                          title="Mark as Problematic"
                          className="p-1 rounded hover:bg-red-100 text-red-600 hover:text-red-700 transition-colors">
                          <XCircle className="w-4 h-4" />
                        </button>
                      </>
                    ) : (
                      <button onClick={() => updateClauseStatus(clause.contract_id, clause.clause_id, 'pending')}
                        className="text-xs text-gray-400 hover:text-gray-600">
                        Reset
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))}
            {filtered.length === 0 && (
              <div className="p-12 text-center text-gray-400">No clauses to display</div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
