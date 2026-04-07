export function RiskBadge({ level }) {
  const config = {
    High: { bg: 'bg-red-100', text: 'text-red-700', dot: 'bg-red-500' },
    Medium: { bg: 'bg-amber-100', text: 'text-amber-700', dot: 'bg-amber-500' },
    Low: { bg: 'bg-green-100', text: 'text-green-700', dot: 'bg-green-500' },
  }
  const c = config[level] || config.Medium
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${c.bg} ${c.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${c.dot}`} />
      {level}
    </span>
  )
}

export function TeamBadge({ team }) {
  const config = {
    'Legal': { bg: 'bg-blue-100', text: 'text-blue-700' },
    'Technical/Ops': { bg: 'bg-purple-100', text: 'text-purple-700' },
    'Sales': { bg: 'bg-emerald-100', text: 'text-emerald-700' },
    'Marketing': { bg: 'bg-orange-100', text: 'text-orange-700' },
  }
  const c = config[team] || { bg: 'bg-gray-100', text: 'text-gray-700' }
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${c.bg} ${c.text}`}>
      {team}
    </span>
  )
}

export function StatusBadge({ status }) {
  const config = {
    'pending': { bg: 'bg-gray-100', text: 'text-gray-600', label: 'Pending' },
    'in_review': { bg: 'bg-blue-100', text: 'text-blue-700', label: 'In Review' },
    'reviewed': { bg: 'bg-green-100', text: 'text-green-700', label: 'Reviewed' },
  }
  const c = config[status] || config.pending
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${c.bg} ${c.text}`}>
      {c.label}
    </span>
  )
}
