import { useState, useEffect, useMemo } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, Calendar, Users, AlertTriangle, CheckCircle, XCircle, Flag, Eye } from 'lucide-react'
import { RiskBadge, TeamBadge, StatusBadge } from './Badges'

const TEAM_COLORS = {
  'Legal': 'border-l-blue-500 bg-blue-50/30',
  'Technical/Ops': 'border-l-purple-500 bg-purple-50/30',
  'Sales': 'border-l-emerald-500 bg-emerald-50/30',
  'Marketing': 'border-l-orange-500 bg-orange-50/30',
}

const TEAM_HIGHLIGHT = {
  'Legal': 'highlight-legal',
  'Technical/Ops': 'highlight-technical',
  'Sales': 'highlight-sales',
  'Marketing': 'highlight-marketing',
}

export default function ContractDetail() {
  const { id } = useParams()
  const [contract, setContract] = useState(null)
  const [clauses, setClauses] = useState([])
  const [activeTeam, setActiveTeam] = useState(null)
  const [activeClause, setActiveClause] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadContract()
  }, [id])

  async function loadContract() {
    setLoading(true)
    try {
      const [contractRes, clausesRes] = await Promise.all([
        fetch(`/api/contracts/${id}`),
        fetch(`/api/contracts/${id}/clauses`)
      ])
      setContract(await contractRes.json())
      setClauses(await clausesRes.json())
    } catch (e) {
      console.error('Failed to load contract:', e)
    }
    setLoading(false)
  }

  async function updateClauseStatus(clauseId, status) {
    try {
      await fetch(`/api/contracts/${id}/clauses/${clauseId}/review`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status })
      })
      setClauses(prev => prev.map(c => c.clause_id === clauseId ? { ...c, review_status: status } : c))
    } catch (e) {
      console.error('Failed to update review status:', e)
    }
  }

  function scrollToClause(clauseId) {
    setActiveClause(clauseId)
    const mark = document.querySelector(`mark[data-clause="${clauseId}"]`)
    if (mark) {
      mark.scrollIntoView({ behavior: 'smooth', block: 'center' })
      mark.classList.add('ring-2', 'ring-snowflake-500', 'ring-offset-1')
      setTimeout(() => mark.classList.remove('ring-2', 'ring-snowflake-500', 'ring-offset-1'), 2000)
    }
  }

  const filteredClauses = useMemo(() => {
    if (!activeTeam) return clauses
    return clauses.filter(c => c.assigned_team === activeTeam)
  }, [clauses, activeTeam])

  const teamCounts = useMemo(() => {
    const counts = {}
    clauses.forEach(c => {
      counts[c.assigned_team] = (counts[c.assigned_team] || 0) + 1
    })
    return counts
  }, [clauses])

  const highlightedText = useMemo(() => {
    if (!contract?.full_text) return ''
    let text = contract.full_text
    const relevantClauses = activeTeam ? filteredClauses : clauses
    const matches = []
    relevantClauses.forEach(clause => {
      if (!clause.clause_text) return
      const searchText = clause.clause_text.substring(0, 100)
      const idx = text.indexOf(searchText)
      if (idx >= 0) {
        matches.push({
          start: idx,
          end: idx + clause.clause_text.length,
          team: clause.assigned_team,
          clauseId: clause.clause_id,
          riskLevel: clause.risk_level,
        })
      }
    })
    matches.sort((a, b) => a.start - b.start)
    if (matches.length === 0) return escapeHtml(text)

    let result = ''
    let lastEnd = 0
    matches.forEach(m => {
      if (m.start < lastEnd) return
      result += escapeHtml(text.substring(lastEnd, m.start))
      const cssClass = TEAM_HIGHLIGHT[m.team] || ''
      const riskClass = m.riskLevel === 'High' ? 'font-semibold' : ''
      result += `<mark class="${cssClass} ${riskClass} cursor-pointer rounded px-0.5" data-clause="${m.clauseId}">`
      result += escapeHtml(text.substring(m.start, m.end))
      result += '</mark>'
      lastEnd = m.end
    })
    result += escapeHtml(text.substring(lastEnd))
    return result
  }, [contract, clauses, filteredClauses, activeTeam])

  function escapeHtml(str) {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br/>')
  }

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-screen">
        <div className="animate-spin w-8 h-8 border-2 border-snowflake-500 border-t-transparent rounded-full" />
      </div>
    )
  }

  if (!contract) {
    return <div className="p-8 text-center text-gray-500">Contract not found</div>
  }

  return (
    <div className="h-screen flex flex-col">
      <div className="bg-white border-b border-gray-200 p-4">
        <div className="flex items-center gap-4 mb-3">
          <Link to="/" className="text-gray-400 hover:text-gray-600"><ArrowLeft className="w-5 h-5" /></Link>
          <div className="flex-1">
            <h1 className="text-lg font-bold text-gray-900">{contract.contract_name}</h1>
            <p className="text-sm text-gray-500">{contract.contract_type}</p>
          </div>
          <RiskBadge level={contract.overall_risk} />
        </div>
        <div className="flex items-center gap-6 text-sm text-gray-500">
          <span className="flex items-center gap-1.5">
            <Users className="w-4 h-4" /> {contract.parties}
          </span>
          {contract.effective_date && contract.effective_date !== 'Not specified' && (
            <span className="flex items-center gap-1.5">
              <Calendar className="w-4 h-4" /> {contract.effective_date} — {contract.expiration_date || '?'}
            </span>
          )}
        </div>
        {contract.summary_text && (
          <p className="mt-2 text-sm text-gray-600 bg-gray-50 rounded-lg p-3">{contract.summary_text}</p>
        )}
        {contract.key_findings && contract.key_findings.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-2">
            {contract.key_findings.map((f, i) => (
              <span key={i} className="inline-flex items-center gap-1 text-xs bg-amber-50 text-amber-700 px-2 py-1 rounded">
                <AlertTriangle className="w-3 h-3" /> {f}
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 overflow-y-auto p-6 bg-white">
          <div className="max-w-4xl mx-auto prose prose-sm">
            <div className="font-mono text-sm leading-relaxed text-gray-700 whitespace-pre-wrap"
              dangerouslySetInnerHTML={{ __html: highlightedText }}
              onClick={e => {
                const mark = e.target.closest('mark')
                if (mark) setActiveClause(mark.dataset.clause)
              }}
            />
          </div>
        </div>

        <div className="w-96 border-l border-gray-200 bg-gray-50 flex flex-col overflow-hidden">
          <div className="p-3 border-b border-gray-200 bg-white">
            <div className="flex gap-1 flex-wrap">
              <button onClick={() => setActiveTeam(null)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                  !activeTeam ? 'bg-snowflake-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}>
                All ({clauses.length})
              </button>
              {Object.entries(teamCounts).map(([team, count]) => (
                <button key={team} onClick={() => setActiveTeam(team)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                    activeTeam === team ? 'bg-snowflake-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}>
                  {team.split('/')[0]} ({count})
                </button>
              ))}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto p-3 space-y-2">
            {filteredClauses.map(clause => (
              <div key={clause.clause_id}
                onClick={() => scrollToClause(clause.clause_id)}
                className={`border-l-4 rounded-lg p-3 bg-white border border-gray-200 cursor-pointer hover:shadow-md transition-shadow ${TEAM_COLORS[clause.assigned_team] || ''} ${
                  activeClause === clause.clause_id ? 'ring-2 ring-snowflake-500' : ''
                }`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-semibold text-gray-700">{clause.clause_type}</span>
                  <div className="flex items-center gap-1.5">
                    <RiskBadge level={clause.risk_level} />
                    <StatusBadge status={clause.review_status} />
                  </div>
                </div>
                <p className="text-xs text-gray-600 line-clamp-3 mb-2">{clause.clause_text}</p>
                <p className="text-xs text-gray-500 italic mb-2">{clause.risk_explanation}</p>
                <div className="flex items-center justify-between">
                  <TeamBadge team={clause.assigned_team} />
                  <div className="flex items-center gap-1" onClick={e => e.stopPropagation()}>
                    {!['approved','flagged','rejected'].includes(clause.review_status) && (
                      <>
                        <button onClick={() => updateClauseStatus(clause.clause_id, 'approved')}
                          title="Approve"
                          className="p-1 rounded hover:bg-green-100 text-green-600 hover:text-green-700 transition-colors">
                          <CheckCircle className="w-4 h-4" />
                        </button>
                        <button onClick={() => updateClauseStatus(clause.clause_id, 'flagged')}
                          title="Flag for Modification"
                          className="p-1 rounded hover:bg-amber-100 text-amber-600 hover:text-amber-700 transition-colors">
                          <Flag className="w-4 h-4" />
                        </button>
                        <button onClick={() => updateClauseStatus(clause.clause_id, 'rejected')}
                          title="Mark as Problematic"
                          className="p-1 rounded hover:bg-red-100 text-red-600 hover:text-red-700 transition-colors">
                          <XCircle className="w-4 h-4" />
                        </button>
                      </>
                    )}
                    {['approved','flagged','rejected'].includes(clause.review_status) && (
                      <button onClick={() => updateClauseStatus(clause.clause_id, 'pending')}
                        className="text-xs text-gray-400 hover:text-gray-600">
                        Reset
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))}
            {filteredClauses.length === 0 && (
              <div className="text-center text-gray-400 text-sm py-8">No clauses for this filter</div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
