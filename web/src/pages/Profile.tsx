import { useEffect, useState, useRef, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Chip from '@mui/material/Chip'
import Alert from '@mui/material/Alert'
import Avatar from '@mui/material/Avatar'
import Typography from '@mui/material/Typography'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableRow from '@mui/material/TableRow'
import Divider from '@mui/material/Divider'
import PhotoCameraIcon from '@mui/icons-material/PhotoCamera'
import SaveIcon from '@mui/icons-material/Save'
import IconButton from '@mui/material/IconButton'
import { supabase } from '../lib/supabase'
import { useSession } from '../App'
import { PageHead, EmptyState, LoadingState, Section, Badge } from '../components/ui'
import { inr } from '../lib/format'

type Award = { id: string; title: string; level: string | null; date: string | null }

const ROLE_LABEL: Record<string, string> = {
  Admin: 'Administrator',
  Coach: 'Coach',
  Athlete: 'Athlete',
  HR: 'Human Resources',
  Finance: 'Finance',
  VenueManager: 'Venue Manager',
}

export default function Profile() {
  const session = useSession()
  const uid = session?.user.id ?? null
  const email = session?.user.email ?? ''
  const role = session?.profile?.role ?? ''

  const [name, setName] = useState('')
  const [contact, setContact] = useState('')
  const [phone, setPhone] = useState('')
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [athlete, setAthlete] = useState<Record<string, unknown> | null>(null)
  const [coach, setCoach] = useState<Record<string, unknown> | null>(null)
  const [awards, setAwards] = useState<Award[]>([])
  const fileRef = useRef<HTMLInputElement>(null)

  const load = useCallback(async () => {
    if (!uid) return
    setLoading(true)
    setError('')
    const { data: p } = await supabase
      .from('profiles')
      .select('full_name, contact_info, phone, avatar_url')
      .eq('id', uid)
      .single()
    setName((p?.full_name as string) ?? '')
    setContact((p?.contact_info as string) ?? '')
    setPhone((p?.phone as string) ?? '')
    setAvatarUrl((p?.avatar_url as string) ?? null)

    if (role === 'Athlete') {
      const { data: a } = await supabase
        .from('athletes')
        .select('*, teams(name), athlete_sports(sports(name))')
        .eq('profile_id', uid)
        .maybeSingle()
      setAthlete((a as unknown as Record<string, unknown>) ?? null)
      const { data: aw } = await supabase
        .from('awards')
        .select('id, title, level, date, athletes!inner(profile_id)')
        .eq('athletes.profile_id', uid)
        .order('date', { ascending: false })
        .limit(10)
      setAwards((aw as unknown as Award[]) ?? [])
    } else if (role === 'Coach') {
      const { data: c } = await supabase
        .from('coaches')
        .select('*, teams(id, name)')
        .eq('profile_id', uid)
        .maybeSingle()
      setCoach((c as unknown as Record<string, unknown>) ?? null)
    }
    setLoading(false)
  }, [uid, role])

  useEffect(() => { load() }, [load])

  async function pickAvatar(file: File) {
    if (!uid) return
    setError('')
    setMsg('')
    if (file.size > 4 * 1024 * 1024) {
      setError('Image must be under 4 MB.')
      return
    }
    setSaving(true)
    try {
      const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg'
      const path = `${uid}/avatar_${Date.now()}.${ext}`
      const { error: upErr } = await supabase.storage
        .from('avatars')
        .upload(path, file, { upsert: true, contentType: file.type })
      if (upErr) throw upErr
      const { data: { publicUrl } } = supabase.storage.from('avatars').getPublicUrl(path)
      const url = `${publicUrl}?v=${Date.now()}`
      const { error: dbErr } = await supabase
        .from('profiles')
        .update({ avatar_url: url })
        .eq('id', uid)
      if (dbErr) throw dbErr
      setAvatarUrl(url)
      setMsg('Profile photo updated.')
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setSaving(false)
    }
  }

  async function save() {
    if (!uid) return
    if (!name.trim()) {
      setError('Name cannot be empty.')
      return
    }
    setSaving(true)
    setError('')
    setMsg('')
    const { error } = await supabase
      .from('profiles')
      .update({
        full_name: name.trim(),
        contact_info: contact.trim() || null,
        phone: phone.trim() || null,
      })
      .eq('id', uid)
    setSaving(false)
    if (error) setError(error.message)
    else setMsg('Profile saved.')
  }

  if (loading) return <LoadingState />

  const sportsTags = ((athlete?.athlete_sports ?? []) as { sports?: { name?: string } }[])
    .map((t) => t.sports?.name)
    .filter(Boolean) as string[]
  const coachTeams = ((coach?.teams ?? []) as { name?: string }[]).map((t) => t.name).filter(Boolean)

  return (
    <Box>
      <PageHead title="My Profile" sub="Your account, photo and personal details." />

      {(error || msg) && (
        <Alert severity={error ? 'error' : 'success'} sx={{ mb: 2 }} onClose={() => { setError(''); setMsg('') }}>
          {error || msg}
        </Alert>
      )}

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '340px 1fr' }, gap: 2 }}>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Box sx={{ position: 'relative', display: 'inline-block' }}>
            <Avatar
              src={avatarUrl ?? undefined}
              sx={(t) => ({
                width: 120,
                height: 120,
                fontSize: 40,
                fontWeight: 700,
                bgcolor: t.palette.primary.main,
              })}
            >
              {!avatarUrl && (name.trim()[0]?.toUpperCase() || '?')}
            </Avatar>
            <IconButton
              size="small"
              onClick={() => fileRef.current?.click()}
              disabled={saving}
              sx={{
                position: 'absolute',
                right: -4,
                bottom: -4,
                bgcolor: 'primary.main',
                color: 'common.white',
                '&:hover': { bgcolor: 'primary.dark' },
              }}
              aria-label="Upload photo"
            >
              <PhotoCameraIcon fontSize="small" />
            </IconButton>
          </Box>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0]
              if (f) pickAvatar(f)
              e.target.value = ''
            }}
          />
          <Typography sx={{ mt: 2, fontWeight: 700, fontSize: 18 }}>{name || '-'}</Typography>
          <Chip size="small" color="primary" label={ROLE_LABEL[role] ?? role} sx={{ mt: 1 }} />
          <Typography variant="body2" sx={{ color: 'text.secondary', mt: 1.5 }}>{email}</Typography>
          <Button
            variant="outlined"
            startIcon={<PhotoCameraIcon />}
            onClick={() => fileRef.current?.click()}
            disabled={saving}
            fullWidth
            sx={{ mt: 2.5 }}
          >
            {saving ? 'Uploading...' : 'Upload photo'}
          </Button>
        </Paper>

        <Box>
          <Section title="Personal details">
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 2 }}>
              <TextField label="Full name" value={name} onChange={(e) => setName(e.target.value)} />
              <TextField label="Email" type="email" value={contact} onChange={(e) => setContact(e.target.value)} />
              {/* Separate phone field — parity with the mobile profile. */}
              <TextField label="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} />
            </Box>
            <Box sx={{ mt: 2 }}>
              <Button variant="contained" startIcon={<SaveIcon />} onClick={save} disabled={saving}>
                Save changes
              </Button>
            </Box>
          </Section>

          <Section title="Account">
            <Table size="small">
              <TableBody>
                <TableRow>
                  <TableCell sx={{ color: 'text.secondary', width: 180 }}>Email</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>{email}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell sx={{ color: 'text.secondary' }}>Role</TableCell>
                  <TableCell><Chip size="small" color="primary" label={ROLE_LABEL[role] ?? role} /></TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </Section>

          {role === 'Athlete' && athlete && (
            <Section title="Athlete record">
              <Table size="small">
                <TableBody>
                  <TableRow><TableCell sx={{ color: 'text.secondary', width: 180 }}>Team</TableCell><TableCell sx={{ fontWeight: 600 }}>{((athlete.teams ?? {}) as { name?: string }).name ?? '-'}</TableCell></TableRow>
                  <TableRow><TableCell sx={{ color: 'text.secondary' }}>Date of birth</TableCell><TableCell sx={{ fontWeight: 600 }}>{(athlete.dob as string) ?? '-'}</TableCell></TableRow>
                  <TableRow><TableCell sx={{ color: 'text.secondary' }}>Sports</TableCell><TableCell sx={{ fontWeight: 600 }}>{sportsTags.join(', ') || '-'}</TableCell></TableRow>
                  <TableRow><TableCell sx={{ color: 'text.secondary' }}>Medical notes</TableCell><TableCell sx={{ fontWeight: 600 }}>{(athlete.medical_notes as string) || '-'}</TableCell></TableRow>
                </TableBody>
              </Table>
            </Section>
          )}

          {role === 'Coach' && coach && (
            <Section title="Coaching record">
              <Table size="small">
                <TableBody>
                  <TableRow><TableCell sx={{ color: 'text.secondary', width: 180 }}>Specialization</TableCell><TableCell sx={{ fontWeight: 600 }}>{(coach.specialization as string) ?? '-'}</TableCell></TableRow>
                  <TableRow><TableCell sx={{ color: 'text.secondary' }}>Teams</TableCell><TableCell sx={{ fontWeight: 600 }}>{coachTeams.join(', ') || '-'}</TableCell></TableRow>
                </TableBody>
              </Table>
            </Section>
          )}

          {role === 'Athlete' && (
            <Section title="Awards & achievements">
              {awards.length === 0 ? (
                <EmptyState text="No awards recorded yet." />
              ) : (
                <Table size="small">
                  <TableBody>
                    {awards.map((a) => (
                      <TableRow key={a.id} hover>
                        <TableCell sx={{ fontWeight: 600 }}>{a.title}</TableCell>
                        <TableCell><Badge color={a.level === 'National' ? 'error' : a.level === 'State' ? 'warning' : 'success'}>{a.level ?? '-'}</Badge></TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{a.date ?? '-'}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </Section>
          )}
        </Box>
      </Box>
      <Divider sx={{ mt: 3 }} />
    </Box>
  )
}
