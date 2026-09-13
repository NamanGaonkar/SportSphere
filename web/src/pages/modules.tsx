import CrudPage from '../components/CrudPage'
import type { ColumnDef, FieldDef } from '../components/CrudPage'
import Box from '@mui/material/Box'
import { Badge, statusColor } from '../components/ui'
import { useSportNameMap } from '../components/SportSelect'

const sportSource = { table: 'sports', select: 'id, name', labelPath: 'name' }
const teamSource = { table: 'teams', select: 'id, name', labelPath: 'name' }
const venueSource = { table: 'venues', select: 'id, name', labelPath: 'name' }
const coachSource = { table: 'coaches', select: 'id, profile:profiles(full_name)', labelPath: 'profile.full_name' }
const athleteSource = { table: 'athletes', select: 'id, profile:profiles(full_name)', labelPath: 'profile.full_name' }

const statusCol = (key: string, label: string): ColumnDef => ({
  key,
  label,
  render: (row) => <Badge color={statusColor(String(row[key] ?? ''))}>{String(row[key] ?? '-')}</Badge>,
})

const moneyCol = (key: string, label: string): ColumnDef => ({
  key,
  label,
  render: (row) => (row[key] == null ? '-' : `Rs ${Number(row[key]).toLocaleString('en-IN')}`),
})

export function Housekeeping() {
  const fields: FieldDef[] = [
    { key: 'area', label: 'Area', required: true },
    { key: 'task', label: 'Task', required: true },
    { key: 'assigned_to', label: 'Assigned to' },
    { key: 'scheduled_date', label: 'Scheduled date', type: 'date' },
    { key: 'status', label: 'Status', type: 'select', options: ['Pending', 'In Progress', 'Done'] },
  ]
  const columns: ColumnDef[] = [
    { key: 'area', label: 'Area' },
    { key: 'task', label: 'Task' },
    { key: 'assigned_to', label: 'Assigned' },
    { key: 'scheduled_date', label: 'Date' },
    statusCol('status', 'Status'),
  ]
  return <CrudPage title="Housekeeping Management" sub="Cleaning and upkeep tasks across venues." table="housekeeping_tasks" columns={columns} fields={fields} searchKeys={['area', 'task', 'assigned_to']} />
}

export function Training() {
  const sportName = useSportNameMap()
  const fields: FieldDef[] = [
    { key: 'title', label: 'Title', required: true },
    { key: 'type', label: 'Type', type: 'select', options: ['Session', 'Camp'] },
    { key: 'sport_id', label: 'Sport', type: 'select', source: sportSource },
    { key: 'coach_id', label: 'Coach', type: 'select', source: coachSource },
    { key: 'team_id', label: 'Team', type: 'select', source: teamSource },
    { key: 'venue_id', label: 'Venue', type: 'select', source: venueSource },
    { key: 'start_time', label: 'Starts', type: 'datetime-local' },
    { key: 'end_time', label: 'Ends', type: 'datetime-local' },
    { key: 'notes', label: 'Notes', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'title', label: 'Title' },
    { key: 'type', label: 'Type' },
    { key: 'sport_id', label: 'Sport', render: (r) => sportName.get(String(r.sport_id ?? '')) ?? '-' },
    { key: 'coach_id', label: 'Coach' },
    { key: 'start_time', label: 'When', render: (r) => r.start_time ? new Date(String(r.start_time)).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '-' },
  ]
  return <CrudPage title="Training & Camps" sub="Training sessions and residential camps." table="training_sessions" columns={columns} fields={fields} searchKeys={['title']} />
}

export function Performance() {
  const fields: FieldDef[] = [
    { key: 'athlete_id', label: 'Athlete', type: 'select', source: athleteSource, required: true },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'metric', label: 'Metric (e.g. 100m Sprint)', required: true },
    { key: 'value', label: 'Result (display)', required: true },
    { key: 'value_num', label: 'Numeric value', type: 'number' },
    { key: 'unit', label: 'Unit (sec / cm / kg / reps)' },
    { key: 'session_type', label: 'Session type', type: 'select', options: ['Test', 'Assessment', 'Gym', 'Competition'] },
    { key: 'coach_note', label: 'Coach note', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'athlete_id', label: 'Athlete' },
    { key: 'date', label: 'Date' },
    { key: 'metric', label: 'Metric', render: (r) => <Box component="span" sx={{ fontWeight: 600 }}>{String(r.metric ?? '-')}</Box> },
    { key: 'value_num', label: 'Result', render: (r) => `${r.value_num ?? r.value ?? '-'} ${r.unit ?? ''}` },
    { key: 'session_type', label: 'Session', render: (r) => <Badge color={r.session_type === 'Competition' ? 'info' : 'default'}>{String(r.session_type ?? 'Test')}</Badge> },
    { key: 'coach_note', label: 'Coach note' },
  ]
  return <CrudPage title="Athlete Performance" sub="Structured metric logging: sprints, jumps, endurance, gym and assessments." table="performance_records" orderBy="date" columns={columns} fields={fields} searchKeys={['metric', 'value']} />
}

export function Medical() {
  const fields: FieldDef[] = [
    { key: 'athlete_id', label: 'Athlete', type: 'select', source: athleteSource, required: true },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'type', label: 'Type', type: 'select', options: ['Checkup', 'Injury', 'Physio', 'Clearance'] },
    { key: 'height_cm', label: 'Height (cm)', type: 'number' },
    { key: 'weight_kg', label: 'Weight (kg)', type: 'number' },
    { key: 'severity', label: 'Severity', type: 'select', options: ['None', 'Mild', 'Moderate', 'Severe'] },
    { key: 'cleared', label: 'Cleared to play', type: 'checkbox' },
    { key: 'treatment', label: 'Treatment', fullWidth: true },
    { key: 'follow_up_date', label: 'Follow-up date', type: 'date' },
    { key: 'details', label: 'Details', type: 'textarea', required: true, fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'athlete_id', label: 'Athlete' },
    { key: 'type', label: 'Type', render: (r) => <Badge color={r.type === 'Injury' ? 'error' : r.type === 'Physio' ? 'warning' : 'info'}>{String(r.type ?? '-')}</Badge> },
    { key: 'details', label: 'Details' },
    { key: 'severity', label: 'Severity', render: (r) => (r.severity && r.severity !== 'None' ? <Badge color={r.severity === 'Severe' ? 'error' : r.severity === 'Moderate' ? 'warning' : 'info'}>{String(r.severity)}</Badge> : '-') },
    { key: 'cleared', label: 'Cleared', render: (r) => <Badge color={r.cleared ? 'success' : 'error'}>{r.cleared ? 'Cleared' : 'Not cleared'}</Badge> },
    { key: 'follow_up_date', label: 'Follow-up', render: (r) => (r.follow_up_date ? new Date(String(r.follow_up_date) + 'T00:00:00').toLocaleDateString() : '-') },
    { key: 'date', label: 'Date' },
  ]
  return <CrudPage title="Athlete Medical" sub="Detailed logging: vitals, injuries, severity, treatment and follow-ups." table="medical_records" orderBy="date" columns={columns} fields={fields} searchKeys={['details']} />
}

export function EventsPage() {
  const fields: FieldDef[] = [
    { key: 'title', label: 'Title', required: true },
    { key: 'type', label: 'Type', type: 'select', options: ['General', 'Ceremony', 'Workshop', 'Other'] },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'venue_id', label: 'Venue', type: 'select', source: venueSource },
    { key: 'description', label: 'Description', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'title', label: 'Title' },
    { key: 'type', label: 'Type' },
    { key: 'date', label: 'Date' },
    { key: 'venue_id', label: 'Venue' },
  ]
  return <CrudPage title="Events Management" sub="Ceremonies, workshops and other events." table="events" columns={columns} fields={fields} searchKeys={['title']} />
}

export function Transport() {
  const fields: FieldDef[] = [
    { key: 'purpose', label: 'Purpose', required: true },
    { key: 'vehicle', label: 'Vehicle' },
    { key: 'driver', label: 'Driver' },
    { key: 'team_id', label: 'Team', type: 'select', source: teamSource },
    { key: 'depart_at', label: 'Departure', type: 'datetime-local' },
    { key: 'return_at', label: 'Return', type: 'datetime-local' },
    { key: 'status', label: 'Status', type: 'select', options: ['Planned', 'In Transit', 'Completed'] },
  ]
  const columns: ColumnDef[] = [
    { key: 'purpose', label: 'Purpose' },
    { key: 'vehicle', label: 'Vehicle' },
    { key: 'driver', label: 'Driver' },
    { key: 'depart_at', label: 'Departure', render: (r) => r.depart_at ? new Date(String(r.depart_at)).toLocaleString() : '-' },
    statusCol('status', 'Status'),
  ]
  return <CrudPage title="Transport" sub="Team travel - buses, vehicles, drivers." table="transport" columns={columns} fields={fields} searchKeys={['purpose', 'vehicle', 'driver']} />
}

export function Accommodation() {
  const fields: FieldDef[] = [
    { key: 'hotel', label: 'Hotel', required: true },
    { key: 'location', label: 'Location' },
    { key: 'team_id', label: 'Team', type: 'select', source: teamSource },
    { key: 'check_in', label: 'Check-in', type: 'date' },
    { key: 'check_out', label: 'Check-out', type: 'date' },
    { key: 'rooms', label: 'Rooms', type: 'number' },
    { key: 'status', label: 'Status', type: 'select', options: ['Booked', 'Checked-in', 'Completed'] },
  ]
  const columns: ColumnDef[] = [
    { key: 'hotel', label: 'Hotel' },
    { key: 'location', label: 'Location' },
    { key: 'check_in', label: 'Check-in' },
    { key: 'check_out', label: 'Check-out' },
    { key: 'rooms', label: 'Rooms' },
    statusCol('status', 'Status'),
  ]
  return <CrudPage title="Accommodation" sub="Hotel stays for teams during travel." table="accommodation" columns={columns} fields={fields} searchKeys={['hotel', 'location']} />
}

export function Expenses() {
  const fields: FieldDef[] = [
    { key: 'category', label: 'Category', type: 'select', options: ['Equipment', 'Travel', 'Salaries', 'Venue', 'Other'], required: true },
    { key: 'amount', label: 'Amount (INR)', type: 'number', required: true },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'description', label: 'Description', type: 'textarea', fullWidth: true },
    { key: 'approved_by', label: 'Approved by' },
  ]
  const columns: ColumnDef[] = [
    { key: 'category', label: 'Category' },
    moneyCol('amount', 'Amount'),
    { key: 'date', label: 'Date' },
    { key: 'description', label: 'Description' },
    { key: 'approved_by', label: 'Approved by' },
  ]
  return <CrudPage title="Finance & Expenses" sub="Organization spending by category." table="expenses" columns={columns} fields={fields} searchKeys={['category', 'description']} />
}

export function Activities() {
  const fields: FieldDef[] = [
    { key: 'title', label: 'Title', required: true },
    { key: 'school', label: 'School' },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'participants', label: 'Participants', type: 'number' },
    { key: 'description', label: 'Description', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'title', label: 'Title' },
    { key: 'school', label: 'School' },
    { key: 'date', label: 'Date' },
    { key: 'participants', label: 'Participants' },
  ]
  return <CrudPage title="School Sports Activities" sub="School-level events and outreach programs." table="school_activities" columns={columns} fields={fields} searchKeys={['title', 'school']} />
}
