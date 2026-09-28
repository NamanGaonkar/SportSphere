# REST API Design Specification

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-API-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | REST API Design Specification |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **API Architecture** | Supabase PostgREST 11+ & GoTrue Authentication Engine |
| **Base URLs** | `https://<supabase-project-ref>.supabase.co/rest/v1/` & `/auth/v1/` |

---

## 1. API Architecture & Standards

SportSphere communicates between its clients (React Web Admin and Flutter Mobile) and backend via Supabase REST APIs. The API layer follows RESTful principles and RFC 7231 standards:

1. **Authentication**: All authenticated requests pass an `Authorization: Bearer <jwt-token>` header along with the required `apikey: <supabase-anon-key>` header.
2. **Access Control**: Every endpoint enforces Row Level Security (RLS) dynamically derived from the JWT claims (`auth.uid()`).
3. **Filtering & Pagination**: PostgREST syntax supports exact matches (`eq`), null checks (`is.null`), ordering (`order=created_at.desc`), and pagination via HTTP `Range` headers or `limit`/`offset` parameters.
4. **Data Format**: Standard JSON payload in both request and response bodies (`Content-Type: application/json`).
5. **Soft Delete Visibility**: Queries on `profiles` automatically append `deleted_at=is.null` for non-admin callers via RLS policy `profiles select visible`.

---

## 2. Authentication API (`/auth/v1/`)

### 2.1 User Login
- **Endpoint**: `POST /auth/v1/token?grant_type=password`
- **Purpose**: Authenticate user and issue JWT token and refresh token.
- **Auth Required**: No (API Key only)
- **Request Body**:
```json
{
  "email": "coach@sportsphere.org",
  "password": "SecretPassword123!"
}
```
- **Response Structure (200 OK)**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "d8a1f3...",
  "user": {
    "id": "e9b28b74-142c-497d-bb61-8254b036987f",
    "email": "coach@sportsphere.org",
    "user_metadata": {
      "full_name": "Marcus Aurelius",
      "role": "Coach"
    }
  }
}
```
- **Error Codes**: `400 Bad Request` (Invalid credentials), `403 Forbidden` (User banned / soft-deleted).

---

### 2.2 User Registration
- **Endpoint**: `POST /auth/v1/signup`
- **Purpose**: Self-register a new user. Public roles are restricted; 'Admin' attempts are demoted.
- **Request Body**:
```json
{
  "email": "athlete@sportsphere.org",
  "password": "Password123!",
  "data": {
    "full_name": "Jordan Bell",
    "role": "Athlete"
  }
}
```
- **Response Structure (200 OK)**:
```json
{
  "id": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9",
  "email": "athlete@sportsphere.org",
  "created_at": "2026-09-28T10:00:00Z"
}
```

---

### 2.3 Password Recovery
- **Endpoint**: `POST /auth/v1/recover`
- **Purpose**: Trigger branded password reset email.
- **Request Body**:
```json
{
  "email": "user@sportsphere.org"
}
```
- **Response Structure (200 OK)**: `{}`

---

## 3. Remote Procedure Call (RPC) API (`/rest/v1/rpc/`)

Specialized administrative operations are executed through database security definer functions:

### 3.1 Soft Delete User
- **Endpoint**: `POST /rest/v1/rpc/admin_delete_user`
- **Purpose**: Soft delete a user profile and ban login access until 2099.
- **Auth Required**: Bearer Token (`Admin` role strictly required).
- **Request Body**:
```json
{
  "p_user": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9"
}
```
- **Response (200 OK)**: `null`
- **Error Responses**:
  - `400 Bad Request`: `{"message": "Only admins can delete users"}`
  - `400 Bad Request`: `{"message": "The fixed admin account cannot be deleted"}`

---

### 3.2 Restore User
- **Endpoint**: `POST /rest/v1/rpc/admin_restore_user`
- **Purpose**: Clear soft-delete timestamp and remove GoTrue auth login ban.
- **Auth Required**: Bearer Token (`Admin` role required).
- **Request Body**:
```json
{
  "p_user": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9"
}
```
- **Response (200 OK)**: `null`

---

### 3.3 Permanently Purge User
- **Endpoint**: `POST /rest/v1/rpc/admin_purge_user`
- **Purpose**: Irrevocably purge user profile, roster rows, and authentication credentials.
- **Auth Required**: Bearer Token (`Admin` role required).
- **Request Body**:
```json
{
  "p_user": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9"
}
```
- **Response (200 OK)**: `null`

---

### 3.4 Role Inspection Helper
- **Endpoint**: `POST /rest/v1/rpc/current_role`
- **Purpose**: Fetch calling user's active role from `public.profiles`.
- **Response (200 OK)**: `"Admin"`

---

## 4. PostgREST Resource Endpoints (`/rest/v1/`)

Every domain table supports standard CRUD operations filtered through RLS.

### 4.1 Profiles Endpoint (`/rest/v1/profiles`)
- **GET `/rest/v1/profiles?select=*&order=created_at.desc`**
  - **Purpose**: Retrieve active user profiles (admins see soft-deleted records too).
  - **Response (200 OK)**:
```json
[
  {
    "id": "e9b28b74-142c-497d-bb61-8254b036987f",
    "full_name": "Marcus Aurelius",
    "role": "Coach",
    "avatar_url": "https://sportsphere.org/avatars/marcus.jpg",
    "contact_info": "coach@sportsphere.org",
    "deleted_at": null,
    "created_at": "2026-09-01T08:00:00Z"
  }
]
```
- **PATCH `/rest/v1/profiles?id=eq.<uuid>`**
  - **Purpose**: Update user profile details.
  - **Request Body**: `{"full_name": "Marcus A. Smith", "contact_info": "+1-555-0199"}`
  - **Response (200 OK)**: Updated row.

---

### 4.2 Sports Catalog (`/rest/v1/sports`)
- **GET `/rest/v1/sports?select=*&order=name.asc`**
  - **Response (200 OK)**:
```json
[
  {
    "id": "3a7b6a12-88ec-43e9-a36c-9a415a770001",
    "name": "Football",
    "icon": "sports_soccer",
    "created_at": "2026-09-01T00:00:00Z"
  }
]
```
- **POST `/rest/v1/sports`** (Admin only)
  - **Request Body**: `{"name": "Rugby", "icon": "sports_rugby"}`
  - **Response (201 Created)**: Created sports record.

---

### 4.3 Teams Endpoint (`/rest/v1/teams`)
- **GET `/rest/v1/teams?select=id,name,sport_id,coach_id,sports(name),coaches(profiles(full_name))`**
  - **Response (200 OK)**:
```json
[
  {
    "id": "7b8f9e12-3456-789a-bcde-f01234567890",
    "name": "Spartans FC Under-19",
    "sport_id": "3a7b6a12-88ec-43e9-a36c-9a415a770001",
    "coach_id": "98765432-10fe-dcba-9876-543210fedcba",
    "sports": {"name": "Football"},
    "coaches": {"profiles": {"full_name": "Marcus Aurelius"}}
  }
]
```
- **POST `/rest/v1/teams`** (Admin or Coach)
  - **Request Body**:
```json
{
  "name": "Spartans Basketball",
  "sport_id": "3a7b6a12-88ec-43e9-a36c-9a415a770003",
  "coach_id": "98765432-10fe-dcba-9876-543210fedcba"
}
```
  - **Response (201 Created)**: Created team entity.

---

### 4.4 Athletes Endpoint (`/rest/v1/athletes`)
- **GET `/rest/v1/athletes?select=id,profile_id,dob,team_id,medical_notes,profiles(full_name,contact_info),teams(name)`**
- **POST `/rest/v1/athletes`** (Admin or Coach)
  - **Request Body**:
```json
{
  "profile_id": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9",
  "dob": "2007-05-14",
  "team_id": "7b8f9e12-3456-789a-bcde-f01234567890",
  "medical_notes": "Mild exercise-induced asthma; inhaler available."
}
```

---

### 4.5 Matches & Scoring Endpoint (`/rest/v1/matches`)
- **GET `/rest/v1/matches?select=*,tournament:tournaments(name),team_a:teams!team_a_id(name),team_b:teams!team_b_id(name)&order=scheduled_at.asc`**
- **PATCH `/rest/v1/matches?id=eq.<uuid>`** (Score Update)
  - **Request Body**:
```json
{
  "status": "Completed",
  "score_a": 3,
  "score_b": 1,
  "result": "Spartans FC won 3-1 in regulation time."
}
```
  - **Response (200 OK)**: Updated match row.

---

### 4.6 Daily Attendance Endpoint (`/rest/v1/attendance`)
- **GET `/rest/v1/attendance?date=eq.2026-09-28&select=*,profiles(full_name,role)`**
- **POST `/rest/v1/attendance`**
  - **Request Body**:
```json
{
  "profile_id": "76495d46-4cb8-4fa3-80c1-3d7756f7e8a9",
  "date": "2026-09-28",
  "status": "Present",
  "leave_reason": null
}
```
  - **Response (201 Created)**: Attendance logged.
  - **Error (409 Conflict)**: Record already exists for this `(profile_id, date)`.

---

### 4.7 Medical Records & Clearances (`/rest/v1/medical_records`)
- **GET `/rest/v1/medical_records?athlete_id=eq.<uuid>&order=date.desc`**
- **POST `/rest/v1/medical_records`** (Admin / Medical staff only)
  - **Request Body**:
```json
{
  "athlete_id": "11223344-5566-7788-99aa-bbccddeeff00",
  "date": "2026-09-28",
  "type": "Injury",
  "details": "Grade 1 hamstring strain during sprint drills. Prescribed 7 days rest and light physio.",
  "cleared": false
}
```
  - **Response (201 Created)**: Medical log recorded; athlete flagged uncleared.

---

### 4.8 Vendors & Purchase Orders (`/rest/v1/purchase_orders`)
- **GET `/rest/v1/purchase_orders?select=*,vendors(name,contact)&order=created_at.desc`**
- **POST `/rest/v1/purchase_orders`** (Admin or Finance)
  - **Request Body**:
```json
{
  "vendor_id": "55443322-1100-ffeeddccbbaa",
  "items": [
    {"name": "FIFA Quality Match Soccer Balls", "qty": 20, "price": 45.00},
    {"name": "Agility Cones (Set of 50)", "qty": 4, "price": 25.00}
  ],
  "total": 1000.00,
  "status": "Ordered"
}
```
  - **Response (201 Created)**: PO generated.

---

### 4.9 Venues & Facilities (`/rest/v1/venues`)
- **GET `/rest/v1/venues?select=*&order=name.asc`**
- **POST `/rest/v1/venues`** (Admin or VenueManager)
  - **Request Body**:
```json
{
  "name": "Main Athletics Stadium",
  "location": "North Campus Sports Complex, Gate 4",
  "capacity": 5000,
  "status": "Active",
  "latitude": 15.498900,
  "longitude": 73.827800
}
```

---

### 4.10 Staff Payroll (`/rest/v1/payroll`)
- **GET `/rest/v1/payroll?select=*,staff(department,designation,profiles(full_name))`**
  - **Security Rule**: Admins and Finance view all; Staff see only their own row.
- **POST `/rest/v1/payroll`** (Finance only)
  - **Request Body**:
```json
{
  "staff_id": "66778899-aabb-ccdd-eeff-001122334455",
  "month": "2026-09-01",
  "gross": 4500.00,
  "deductions": 450.00
}
```
  - **Response (201 Created)**: Created row with computed `net = 4050.00`.

---

### 4.11 Operational Expenses (`/rest/v1/expenses`)
- **GET `/rest/v1/expenses?order=date.desc`**
- **POST `/rest/v1/expenses`** (Finance / Admin)
  - **Request Body**:
```json
{
  "category": "Travel",
  "amount": 850.00,
  "date": "2026-09-28",
  "description": "Charter bus rental for State Championship semifinal away fixture.",
  "approved_by": "Finance Director"
}
```

---

### 4.12 Logistics: Transport & Accommodation
- **`GET / POST / PATCH / DELETE /rest/v1/transport`**
  - Supports tracking team bus routing, vehicle details, driver names, and transit statuses (`Planned`, `In Transit`, `Completed`).
- **`GET / POST / PATCH / DELETE /rest/v1/accommodation`**
  - Coordinates hotel bookings, room counts, and check-in/out schedules for traveling squads.

---

## 5. Error Handling & Standard Status Codes

| HTTP Status | Meaning | Typical Occurrence in SportSphere |
|---|---|---|
| `200 OK` | Success | Successful GET, PATCH, or RPC execution. |
| `201 Created` | Resource Created | Successful POST entity insertion. |
| `204 No Content` | Deleted | Successful DELETE query. |
| `400 Bad Request` | Validation Error | Missing mandatory column or trigger exception (e.g., attempt to delete root admin). |
| `401 Unauthorized` | Auth Required | Missing or expired Bearer token. |
| `403 Forbidden` | RLS Violation | Non-admin attempting to access restricted tables (e.g. payroll, user purge). |
| `404 Not Found` | Not Found | Target ID does not match any existing record. |
| `409 Conflict` | Unique Violation | Duplicate attendance entry for `(profile_id, date)` or duplicate sport name. |
| `500 Server Error` | Server Exception | Unhandled PostgreSQL database error or network failure. |
