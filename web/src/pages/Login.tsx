import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export default function Login() {
  const [mode, setMode] = useState<'in' | 'up'>('in')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [role, setRole] = useState('Athlete')
  const [showPw, setShowPw] = useState(false)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const navigate = useNavigate()

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setBusy(true)

    if (mode === 'up') {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: fullName, role } },
      })
      setBusy(false)
      if (error) { setError(error.message); return }
      // autoconfirm is enabled → signed in immediately
      navigate('/')
      return
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setBusy(false)
    if (error) { setError(error.message); return }
    navigate('/')
  }

  return (
    <div className="auth-wrap">
      <div className="auth-card">
        <div className="logo">Sport<span>Sphere</span></div>
        <div className="sub">Sports organization management platform</div>
        <form onSubmit={submit}>
          {mode === 'up' && (
            <>
              <div className="form-row">
                <label>Full name</label>
                <input value={fullName} onChange={(e) => setFullName(e.target.value)} required />
              </div>
              <div className="form-row">
                <label>I am a</label>
                <select value={role} onChange={(e) => setRole(e.target.value)}>
                  <option>Athlete</option>
                  <option>Coach</option>
                </select>
              </div>
            </>
          )}
          <div className="form-row">
            <label>Email</label>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@org.com" required />
          </div>
          <div className="form-row">
            <label>Password</label>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                type={showPw ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                minLength={6}
                style={{ flex: 1 }}
              />
              <button type="button" className="btn secondary" onClick={() => setShowPw(!showPw)} style={{ padding: '9px 12px' }}>
                {showPw ? '🙈' : '👁'}
              </button>
            </div>
          </div>
          {error && <div className="error-text">{error}</div>}
          <button className="btn" style={{ width: '100%' }} disabled={busy}>
            {busy ? 'Please wait…' : mode === 'up' ? 'Create account' : 'Sign in'}
          </button>
        </form>
        <div style={{ marginTop: 14, textAlign: 'center', fontSize: 13 }}>
          {mode === 'in' ? (
            <a href="#" onClick={(e) => { e.preventDefault(); setMode('up'); setError('') }}>Don't have an account? Sign up</a>
          ) : (
            <a href="#" onClick={(e) => { e.preventDefault(); setMode('in'); setError('') }}>Already have an account? Sign in</a>
          )}
        </div>
        <div className="demo-accounts">
          <div style={{ marginBottom: 6 }}>Demo accounts (password <code>Passw0rd!</code>):</div>
          <div><code>admin@sportsphere.app</code> — Admin</div>
          <div><code>coach@sportsphere.app</code> — Coach</div>
          <div><code>athlete@sportsphere.app</code> — Athlete</div>
        </div>
      </div>
    </div>
  )
}
