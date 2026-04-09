import { useState, useEffect } from 'react'
import { FlaskConical, Clock, Coins, Target, BarChart3, ChevronDown, ChevronRight } from 'lucide-react'

const METRIC_LABELS = {
  clause_detection_precision: 'Precision',
  clause_detection_recall: 'Recall',
  clause_detection_f1: 'F1 Score',
  team_accuracy: 'Team Accuracy',
  text_overlap_jaccard: 'Text Overlap',
}

const METHOD_LABELS = {
  complete: 'COMPLETE (mistral-large2)',
  ai_extract: 'AI_EXTRACT',
  hybrid: 'AI_EXTRACT + AI_CLASSIFY',
}

function MetricBar({ value, color = 'bg-snowflake-500' }) {
  const pct = Math.round(value * 100)
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <span className="text-xs font-mono text-gray-600 w-10 text-right">{pct}%</span>
    </div>
  )
}

function ComparisonTable({ runs }) {
  if (!runs.length) return null
  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
        <h3 className="text-sm font-semibold text-gray-700">Method Comparison</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-200">
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Method</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Contracts</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Clauses</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Wall Time</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Avg/Contract</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">F1 Score</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Team Acc.</th>
              <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Text Overlap</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {runs.map(r => (
              <tr key={r.run_id} className="hover:bg-gray-50">
                <td className="px-4 py-3">
                  <span className="text-sm font-medium text-gray-900">{METHOD_LABELS[r.method] || r.method}</span>
                  <span className="block text-xs text-gray-400 font-mono">{r.run_id}</span>
                </td>
                <td className="px-4 py-3 text-sm text-gray-600">{r.contract_count}</td>
                <td className="px-4 py-3 text-sm text-gray-600">{r.clause_count || '—'}</td>
                <td className="px-4 py-3 text-sm text-gray-600">
                  {r.total_wall_time_secs ? `${Math.round(r.total_wall_time_secs)}s` : '—'}
                </td>
                <td className="px-4 py-3 text-sm text-gray-600">
                  {r.total_wall_time_secs && r.contract_count
                    ? `${(r.total_wall_time_secs / r.contract_count).toFixed(1)}s`
                    : '—'}
                </td>
                <td className="px-4 py-3 w-40">
                  {r.metrics?.clause_detection_f1 != null
                    ? <MetricBar value={r.metrics.clause_detection_f1} />
                    : <span className="text-xs text-gray-400">—</span>}
                </td>
                <td className="px-4 py-3 w-40">
                  {r.metrics?.team_accuracy != null
                    ? <MetricBar value={r.metrics.team_accuracy} color="bg-emerald-500" />
                    : <span className="text-xs text-gray-400">—</span>}
                </td>
                <td className="px-4 py-3 w-40">
                  {r.metrics?.text_overlap_jaccard != null
                    ? <MetricBar value={r.metrics.text_overlap_jaccard} color="bg-amber-500" />
                    : <span className="text-xs text-gray-400">—</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function RunDetail({ runId }) {
  const [details, setDetails] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`/api/experiments/${runId}`)
      .then(r => r.json())
      .then(setDetails)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [runId])

  if (loading) return <div className="p-4 text-sm text-gray-400">Loading details...</div>
  if (!details) return null

  return (
    <div className="mt-2 bg-gray-50 rounded-lg p-4">
      <h4 className="text-xs font-semibold text-gray-500 uppercase mb-3">Per-Contract Results</h4>
      <div className="space-y-2">
        {details.contracts?.map(c => (
          <div key={c.contract_id} className="bg-white rounded-lg border border-gray-200 p-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-700 font-mono">{c.contract_id}</span>
              <span className="text-xs text-gray-400">
                {c.wall_time_ms ? `${(c.wall_time_ms / 1000).toFixed(1)}s` : '—'} · {c.clause_count || 0} clauses
              </span>
            </div>
            {c.metrics && Object.keys(c.metrics).length > 0 && (
              <div className="grid grid-cols-5 gap-3">
                {Object.entries(c.metrics).map(([k, v]) => (
                  <div key={k}>
                    <span className="text-xs text-gray-400">{METRIC_LABELS[k] || k}</span>
                    <MetricBar value={v} color={k.includes('f1') ? 'bg-snowflake-500' : k.includes('team') ? 'bg-emerald-500' : 'bg-amber-500'} />
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

export default function ExperimentDashboard() {
  const [runs, setRuns] = useState([])
  const [loading, setLoading] = useState(true)
  const [expandedRun, setExpandedRun] = useState(null)

  useEffect(() => {
    fetch('/api/experiments/runs')
      .then(r => r.json())
      .then(setRuns)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  const completedRuns = runs.filter(r => r.total_wall_time_secs)

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">AI Pipeline Experiments</h1>
        <p className="text-sm text-gray-500 mt-1">
          Compare COMPLETE vs AI_EXTRACT vs AI_CLASSIFY pipelines on CUAD ground truth
        </p>
      </div>

      {loading ? (
        <div className="p-12 text-center text-gray-400">
          <div className="animate-spin w-8 h-8 border-2 border-snowflake-500 border-t-transparent rounded-full mx-auto mb-3" />
          Loading experiments...
        </div>
      ) : runs.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <FlaskConical className="w-12 h-12 text-gray-300 mx-auto mb-3" />
          <h3 className="text-lg font-medium text-gray-600">No experiments yet</h3>
          <p className="text-sm text-gray-400 mt-1">
            Run <code className="bg-gray-100 px-1.5 py-0.5 rounded text-xs">python scripts/run_experiments.py</code> to start
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          <div className="grid grid-cols-4 gap-4">
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">Total Runs</p>
                  <p className="text-3xl font-bold mt-1 text-gray-900">{runs.length}</p>
                </div>
                <div className="w-12 h-12 bg-snowflake-50 rounded-lg flex items-center justify-center">
                  <FlaskConical className="w-6 h-6 text-snowflake-500" />
                </div>
              </div>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">Methods Tested</p>
                  <p className="text-3xl font-bold mt-1 text-gray-900">
                    {new Set(runs.map(r => r.method)).size}
                  </p>
                </div>
                <div className="w-12 h-12 bg-purple-50 rounded-lg flex items-center justify-center">
                  <BarChart3 className="w-6 h-6 text-purple-500" />
                </div>
              </div>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">Best F1</p>
                  <p className="text-3xl font-bold mt-1 text-gray-900">
                    {completedRuns.length > 0
                      ? `${Math.round(Math.max(...completedRuns.filter(r => r.metrics?.clause_detection_f1).map(r => r.metrics.clause_detection_f1 * 100)) || 0)}%`
                      : '—'}
                  </p>
                </div>
                <div className="w-12 h-12 bg-green-50 rounded-lg flex items-center justify-center">
                  <Target className="w-6 h-6 text-green-500" />
                </div>
              </div>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">Fastest Run</p>
                  <p className="text-3xl font-bold mt-1 text-gray-900">
                    {completedRuns.length > 0
                      ? `${Math.round(Math.min(...completedRuns.map(r => r.total_wall_time_secs)))}s`
                      : '—'}
                  </p>
                </div>
                <div className="w-12 h-12 bg-amber-50 rounded-lg flex items-center justify-center">
                  <Clock className="w-6 h-6 text-amber-500" />
                </div>
              </div>
            </div>
          </div>

          <ComparisonTable runs={runs} />

          <div className="bg-white rounded-xl border border-gray-200">
            <div className="px-4 py-3 border-b border-gray-200 bg-gray-50">
              <h3 className="text-sm font-semibold text-gray-700">Run Details</h3>
            </div>
            <div className="divide-y divide-gray-100">
              {runs.map(r => (
                <div key={r.run_id}>
                  <button
                    onClick={() => setExpandedRun(expandedRun === r.run_id ? null : r.run_id)}
                    className="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      {expandedRun === r.run_id
                        ? <ChevronDown className="w-4 h-4 text-gray-400" />
                        : <ChevronRight className="w-4 h-4 text-gray-400" />}
                      <span className="text-sm font-medium text-gray-700">
                        {METHOD_LABELS[r.method] || r.method}
                      </span>
                      <span className="text-xs text-gray-400 font-mono">{r.run_id}</span>
                    </div>
                    <span className="text-xs text-gray-400">
                      {r.contract_count} contracts · {r.clause_count || '?'} clauses
                    </span>
                  </button>
                  {expandedRun === r.run_id && <RunDetail runId={r.run_id} />}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
