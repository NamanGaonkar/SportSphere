import { useState, useRef } from 'react'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Chip from '@mui/material/Chip'
import UploadFileIcon from '@mui/icons-material/UploadFile'
import { supabase } from '../lib/supabase'

/**
 * MUI file upload bound to the `documents` storage bucket. The chosen file
 * is uploaded immediately; `value`/`onChange` carry the public URL string
 * so CrudPage treats it exactly like any other text field in the payload.
 */
export default function FileField({
  label,
  value,
  onChange,
}: {
  label: string
  value: string
  onChange: (url: string) => void
}) {
  const [busy, setBusy] = useState(false)

  async function pick(file: File | null) {
    if (!file) return
    setBusy(true)
    try {
      const path = `shared/${Date.now()}_${file.name.replace(/\s+/g, '_')}`
      const { error } = await supabase.storage.from('documents').upload(path, file, { upsert: true })
      if (error) throw error
      const { data } = supabase.storage.from('documents').getPublicUrl(path)
      onChange(data.publicUrl)
    } finally {
      setBusy(false)
    }
  }

  const fileName = value ? decodeURIComponent(value.split('/').pop() ?? '') : ''

  return (
    <Box>
      <Button
        variant="outlined"
        component="label"
        startIcon={<UploadFileIcon />}
        size="small"
        disabled={busy}
        fullWidth
        sx={{ justifyContent: 'flex-start', textTransform: 'none' }}
      >
        {busy ? 'Uploading…' : label}
        <input
          type="file"
          hidden
          accept=".pdf,.png,.jpg,.jpeg,.webp"
          onChange={(e) => pick(e.target.files?.[0] ?? null)}
        />
      </Button>
      {fileName && (
        <Chip
          size="small"
          label={fileName}
          onDelete={() => onChange('')}
          sx={{ mt: 1, maxWidth: '100%' }}
        />
      )}
    </Box>
  )
}
