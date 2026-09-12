import CrudPage from '../components/CrudPage'
import type { ColumnDef, FieldDef } from '../components/CrudPage'
import { Badge, statusColor } from '../components/ui'

const vendorSource = { table: 'vendors', select: 'id, name', labelPath: 'name' }
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

export function Purchases() {
  const fields: FieldDef[] = [
    { key: 'vendor_id', label: 'Vendor', type: 'select', source: vendorSource },
    { key: 'status', label: 'Status', type: 'select', options: ['Draft', 'Ordered', 'Received', 'Cancelled'] },
    { key: 'total', label: 'Total (INR)', type: 'number' },
    { key: 'items', label: 'Items (JSON: [{"name","qty","price"}])', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'vendor_id', label: 'Vendor' },
    { key: 'items', label: 'Items', render: (r) => {
        const items = Array.isArray(r.items) ? r.items as { name: string; qty: number }[] : []
        return items.map((i) => `${i.name} x${i.qty}`).join(', ') || '-'
      } },
    moneyCol('total', 'Total'),
    statusCol('status', 'Status'),
  ]
  return <CrudPage title="Vendor & Purchase Management" sub="Purchase orders against vendors." table="purchase_orders" columns={columns} fields={fields} />
}

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
  const fields: FieldDef[] = [
    { key: 'title', label: 'Title', required: true },
    { key: 'type', label: 'Type', type: 'select', options: ['Session', 'Camp'] },
    { key: 'sport', label: 'Sport' },
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
    { key: 'sport', label: 'Sport' },
    { key: 'coach_id', label: 'Coach' },
    { key: 'start_time', label: 'When', render: (r) => r.start_time ? new Date(String(r.start_time)).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '-' },
  ]
  return <CrudPage title="Training & Camps" sub="Training sessions and residential camps." table="training_sessions" columns={columns} fields={fields} searchKeys={['title', 'sport']} />
}

export function Performance() {
  const fields: FieldDef[] = [
    { key: 'athlete_id', label: 'Athlete', type: 'select', source: athleteSource, required: true },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'metric', label: 'Metric', required: true },
    { key: 'value', label: 'Value', required: true },
    { key: 'notes', label: 'Notes', type: 'textarea', fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'athlete_id', label: 'Athlete' },
    { key: 'date', label: 'Date' },
    { key: 'metric', label: 'Metric' },
    { key: 'value', label: 'Value' },
    { key: 'notes', label: 'Notes' },
  ]
  return <CrudPage title="Athlete Performance" sub="Measured metrics: sprints, jumps, endurance and more." table="performance_records" columns={columns} fields={fields} searchKeys={['metric', 'value']} />
}

export function Medical() {
  const fields: FieldDef[] = [
    { key: 'athlete_id', label: 'Athlete', type: 'select', source: athleteSource, required: true },
    { key: 'date', label: 'Date', type: 'date' },
    { key: 'type', label: 'Type', type: 'select', options: ['Checkup', 'Injury', 'Physio', 'Clearance'] },
    { key: 'cleared', label: 'Cleared to play', type: 'checkbox' },
    { key: 'details', label: 'Details', type: 'textarea', required: true, fullWidth: true },
  ]
  const columns: ColumnDef[] = [
    { key: 'athlete_id', label: 'Athlete' },
    { key: 'type', label: 'Type' },
    { key: 'details', label: 'Details' },
    { key: 'cleared', label: 'Cleared', render: (r) => <Badge color={r.cleared ? 'success' : 'error'}>{r.cleared ? 'Cleared' : 'Not cleared'}</Badge> },
    { key: 'date', label: 'Date' },
  ]
  return <CrudPage title="Athlete Medical" sub="Checkups, injuries, physio and clearances." table="medical_records" columns={columns} fields={fields} searchKeys={['details']} />
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
