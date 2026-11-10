# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**TIA HRMS — native iOS app** (Swift + SwiftUI, MVVM; home-screen name **TIA HRMS** since v1.14, formerly "Tertiary HRMS"). The App Store build of Tertiary
Infotech Academy's HR Management System, **rebuilt fully native — no Capacitor, no WebView**.
Deployment target **iOS 16**, **iPhone only**, **one light TIA premium-blue theme** (10 Nov 2026; BRAND.md in
`../../tertiary/tia-hrms-brand/`): pale blue-white surface (`Theme.backdrop`), white cards, navy-950 #0D1638 text
(`Theme.ink`), navy-grey secondary text (`Theme.mist`), royal-600 #2F5BE6 primary (`Theme.sky`/`premier`), gold-400
#F5B83D only as a sparing accent (accreditation badges), darkened status colours (`Theme.success/warning/danger`).
The navy→royal brand gradient (`Theme.brand`) is for the brand mark only. **No dark mode**: the root forces
`.preferredColorScheme(.light)` — never add a dark/theme toggle or `.white` text on the light surface. On a royal fill (`Theme.accent`/`premier`: initials avatars, accent buttons) text is always `.white`, never navy (Alfred, 11 Nov 2026). App icon (since 1.15): saturated premium-blue master `../../tertiary/tia-hrms-brand/icon-1024.png` (generator `scripts/make_app_icon.swift`), shared with Android.
**This app is the design reference the Android app mirrors 1:1** — follow Apple HIG and the
`mobile-ios-design` skill for new screens.

## Relationship to the web app (hrms.tertiaryinfotech.com) and Coolify

This native app is a **client of the existing HRMS web backend** — it has no database of its own.

- The web app is a **Next.js 14** application deployed on **Coolify** at
  **`https://hrms.tertiaryinfotech.com`**, backed by a **PostgreSQL** database that also runs on
  the company's Coolify host. (The same Next.js codebase lives in the `tertiary-hrms` repo.)
- **The parent web tool's source is checked out locally at
  `/Users/alfredang/projects/tertiary/tertiary-hrms`** — refer to it directly to confirm how
  anything is done server-side (API route contracts under `src/app/api/**`, RBAC in
  `src/lib/mobile-api.ts` + `src/lib/utils.ts` `hasAdminAccess`, Prisma schema, validation
  schemas). It is the source of truth for the mobile app's endpoints. Note: the Coolify
  PostgreSQL (`DATABASE_URL` in that repo's `.env`) is on a private host and is **not reachable
  from a dev machine** — verify data through the authenticated API or the web admin UI, not a
  direct DB connection.
- The iOS app **pulls all of its data from that Coolify deployment over HTTPS**. It never talks to
  PostgreSQL directly; every read/write goes through the web app's authenticated API, so all
  business rules, RBAC, and validation stay on the server — the single source of truth.
- **Authentication** reuses the web app's **NextAuth (Auth.js)** session. `Services/AuthService.swift`
  performs the standard NextAuth flow against Coolify: `GET /api/auth/csrf` →
  `POST /api/auth/callback/{credentials|otp}` → `GET /api/auth/session`. The resulting session cookie
  is stored in the shared cookie jar and reused for every subsequent API call, exactly as a browser
  would. **Email + password**, **email one-time-code (OTP)**, and **Google** sign-in are supported.
- **Google sign-in** (`Services/GoogleSignInService.swift`) uses Apple's `ASWebAuthenticationSession`
  with an OAuth 2.0 **authorization-code + PKCE** flow — no third-party SDK, so the project stays on
  system frameworks only. It exchanges the code for a Google `id_token` and POSTs it to the
  pre-existing **`POST /api/auth/google-mobile`**, which verifies the token with Google, checks the
  audience against `GOOGLE_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` / `GOOGLE_ANDROID_CLIENT_ID`, blocks
  INACTIVE employees, and sets the same NextAuth session cookie. Setup, both sides:
  1. **Google Cloud Console** → *APIs & Services → Credentials → Create credentials → OAuth client
     ID → iOS*, bundle id `com.tertiaryinfotech.hrportal`. An iOS client has **no secret** — the id
     is a public value, and trust comes from the server verifying every token.
  2. In `project.yml`, set `GOOGLE_IOS_CLIENT_ID` to that id and `GOOGLE_IOS_URL_SCHEME` to the same
     id with its dot-separated components **reversed** (`123-abc.apps.googleusercontent.com` →
     `com.googleusercontent.apps.123-abc`), then `xcodegen generate`. Both feed `Info.plist`
     (`GIDClientID` + `CFBundleURLTypes`). Left empty, the app **hides the Google button** entirely.
  3. On the **web app**, paste the same id into *Settings → Credentials → **Mobile Sign-In
     (Google)*** so the backend accepts tokens minted for the iOS client. It is stored in
     `CompanyCredential` and read live — **no redeploy needed**. (A `GOOGLE_IOS_CLIENT_ID` env var
     on Coolify still works as a fallback.)
- **Expired company Google token**: the Gmail/Drive refresh token that sends OTP emails expires
  periodically. An admin renews it in one click at **Settings → Credentials → "Sign in with Google
  to renew token"** (`/api/settings/google-oauth/start`) — the OAuth Playground is only a fallback.
- **Data endpoints**: the web app's pages are server-rendered (React Server Components) and don't
  expose JSON, so a small, **additive `/api/mobile/*` namespace was added to the web
  backend** purely to feed this app (`summary`, `profile`, `leave`, `employees`, `expenses`,
  `payslips`, `calendar`, plus writes: `claims` POST for receipt-photo claim submission and
  `attendance` + `attendance/clock-{in,out}` for clock punches). These endpoints only re-expose
  data/flows the web app already owns and do **not** change any existing web page or behaviour.
  The app also calls a few pre-existing endpoints (`/api/timesheet`, `/api/leave` POST for
  applying, `/api/payroll/payslip/{id}/pdf`).
- **Deploy coupling**: because the mobile data endpoints live in the web backend, new mobile data
  needs (new fields/endpoints) require a change in the `tertiary-hrms` repo and a Coolify redeploy
  (its build runs `prisma db push`). Changing the deployed URL/scheme means updating
  `AuthService.baseURL` here.

## Features

**Included** (HR modules — mirrors the web app for an employee):
- **Login frontend** — TIA premium-blue email + password, email-OTP, and **Google sign-in**; session
  persists across launches.
- **Dashboard** — leave balances (AL / MC / OT), expenses YTD, quick actions, and (for
  approvers — role ADMIN/HR/MANAGER, i.e. `summary.isAdmin`) the **actionable approvals queue**.
  Carries the notifications **bell with unread badge** (`brandBar(bell:)`).
- **Leave** — balances, full request history, and **apply for leave** with a **live working-days
  preview** (weekends + SG public holidays auto-excluded, computed client-side in
  `Theme/WorkingDays.swift` from the public `GET /api/public-holidays?year=` — plain `yyyy-MM-dd`,
  parsed via `Fmt.ymdDate`; the server still computes the authoritative deduction/proration).
  Medical leave attaches an **MC photo** (camera/library → `POST /api/upload` → attached to the request).
  **Leave rules (v1.14, server-enforced; `Models/LeaveRules.swift`)**: `POST /api/leave` 400s carry a
  `code` decoded into `LeaveSubmitError` — `AL_EXCEEDS_BALANCE` (shows the message + NPL figures and an
  **"Apply as No Pay Leave instead"** button that resubmits the same dates with the `NPL` type id),
  `INTERN_MC_NOT_PAID`, `NPL_CAP_EXCEEDED`. Interns (`roles` exactly `["INTERN"]`) picking MC are
  switched to No Pay Leave up front with reason "Sick leave (MC)" and the MC photo kept (mirrors the
  web form's `internSick`). The Leave tab shows the **No Pay Leave** card from the NPL balance row
  (`proRated` = prorated 21-day cap, `available` = remaining).
- **Trainer Management** (Trainer Admins only, More → Manage) — `TrainersView` loads the whole list once
  (`GET /api/mobile/trainers`) and filters on the device with `TrainerDirectory` (mirrors the web
  `filterTrainers` / `topTags`): `.searchable` with skill / certification suggestions + counts that become
  removable tokens, one Filters menu (ACLP/ACTA/DACE/DDDLP/Finance/IBF Fit, Trainers/Applicants), compact rows
  (name, badges, matching skill first) with a contact menu (call / WhatsApp `wa.me/65XXXXXXXX` for 8-digit SG
  numbers / email / copy — `ContactLinks`). `TrainerProfileView` over `GET /api/mobile/trainers/{id}` (NRIC masked
  `S****567D` with a Show toggle; Call / WhatsApp / Email / Copy buttons; collapsible sections). Shown only when `summary.canManageTrainers`
  (role TRAINER_ADMIN); the server returns 403 otherwise. Models in `Models/TrainerModels.swift`,
  decoded leniently (importer-built JSON).
- **Approvals** (approvers only) — approve/reject pending **leave, time off & expense** requests in-app
  (`GET /api/mobile/approvals` + `GET /api/time-off` (approvers get everyone's); actions
  `POST /api/leave|time-off|expenses/{id}/approve|reject`). Leave and time off are **one-line tables**
  (`OneLineTable` in `Views/Components/NeatComponents.swift`: frozen name column, the rest scrolls sideways;
  order name, status, type, dates, days, applied, reason) — a tap opens `RecordSheet` with the full reason
  and Approve / Reject. Time Off has a Mine / Team switch for approvers; Leave & MC has People / Requests. Gated by
  `summary.isAdmin`; **enforced server-side** (403 for staff/interns), not just hidden in the UI.
- **Team** — company directory (richer contact fields for supervisory roles). Approvers tap a
  person for `EmployeeRecordsView` (`GET /api/mobile/employees/{id}/records`, approver-or-self):
  clock-in history (→ full clock in/out list by month), MC history (codes MC/SL) and leave history.
- **Payslips** — list of personal payslips with a native **PDFKit** viewer for the authenticated payslip PDF.
- **Expenses** — personal expense claims with status and approved totals, plus **submit a claim
  with a receipt photo** (camera or library → `POST /api/mobile/claims` multipart → the server
  files the photo in the employee's own Google Drive folder under "Expense Claims" /
  "Medical Claims" and raises the approval). Expense and Medical claim types.
- **Clock In / Out** — `ClockView`: clock in / out with a live elapsed timer and a **monthly daily
  history** (check-in, check-out, hours, month total — `AttendanceHistorySection` over
  `/api/mobile/attendance/history?month=`), one-tap punches stored centrally in `AttendancePunch`.
- **Timesheet = interns only** (`Views/TimesheetViews.swift`, mirrors the web 10 Nov 2026):
  approvers get ONE `TimesheetAdminView` (More → Manage → Timesheet) — pending missing punches
  (`GET /api/attendance/corrections?scope=all&status=PENDING`, approve/reject `POST /api/attendance/corrections/{id}`),
  Off In Lieu entries (`GET/POST /api/timesheet/admin`) and every intern's days + hours for a month
  (`/api/mobile/attendance/summary?month=`), tap an intern → `InternAttendanceDetailView`. The separate
  "Intern Attendance" screen is gone. Interns see `MyTimesheetView`; other staff see **Off In Lieu**
  (`WeeklyTimesheetView`, weekend / PH hours) and no Timesheet.
- **Notifications** — in-app list + nav-bar bell with unread badge. `GET /api/notifications`
  (raw array), mark-read `POST /api/notifications/{id}/read`; filtered to staff-relevant types
  (LEAVE_/OT_/WOODS_SQUARE_ APPROVED/REJECTED/DECLINED, INFO). `NotificationStore` keeps the badge in sync.
- **Calendar** — a **month grid of the whole team's approved leave** (`GET /api/mobile/team-calendar`),
  with an Everyone / Only me filter and a per-day detail sheet. A colleague's leave **type** is masked
  server-side unless the viewer is the person themselves or an approver — medical leave would otherwise
  disclose health information company-wide. Only APPROVED leave is returned.
- **Profile** — full employee record, with **self-service Edit** (`PATCH /api/employees/{id}`,
  `personalInfo` block; `id` = internal employee id) and **Change Password**
  (`PATCH /api/profile/password`, min-6). Employment/role fields stay admin-only (web).

**Excluded** (by product decision):
- **Accounting module** entirely (bank-statement import, transaction dedupe, reconciliation, income/expense tracking) — finance/back-office only, not part of the mobile employee experience.
- **Admin authoring/management** flows that are heavy form/desktop work (creating employees, generating payroll, editing company settings, credential management, email templates). Approvals counts are surfaced on the dashboard, but bulk admin is done on the web.
- **Woods Square building access** — not part of the mobile employee experience (product decision).

## Push notifications (since 1.15)
- `Services/PushManager.swift` + `AppDelegate` (`@UIApplicationDelegateAdaptor`): after sign-in it asks for alert/badge/sound, registers with APNs and POSTs the hex token to `/api/mobile/push-token` `{token, platform:"ios", environment: sandbox|production}` (DEBUG = sandbox); sign-out DELETEs it **before** the session cookie is cleared. A tapped push sets `pendingLink` (the payload's web `link`); `MainTabView` maps it through `PushRoute.from(link:isAdmin:isIntern:)` to a tab or a sheet. The in-app Notifications list routes the same way.
- Entitlement `Support/TertiaryHRMSiOSApp.entitlements` uses `$(APS_ENVIRONMENT)` (Debug development / Release production, set per config in `project.yml`). Push is enabled on the App ID; the manual App Store profile **"HRMS App Store API"** was regenerated with push on 11 Nov 2026. If a capability is ever added again, regenerate that profile (ASC API `POST /v1/profiles`, IOS_APP_STORE, cert JU3U329V25) or export fails with "doesn't include the aps-environment entitlement".
- Xcode has no Apple ID signed in on this Mac: archive/export with `-allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8 -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID`.
- The APNs auth key for the server is `B8VV93SZCQ` (team GU9WTSTX9M); the server holds it, never this repo.

## Build & run

Unit tests (`TertiaryHRMSiOSAppTests/`: leave-rule error decoding + trainer payloads):
`xcodebuild test -project TertiaryHRMSiOSApp.xcodeproj -scheme TertiaryHRMSiOSApp -destination 'platform=iOS Simulator,name=<sim>' CODE_SIGNING_ALLOWED=NO`

The `.xcodeproj` is **generated by XcodeGen and gitignored** — never edit it by hand; edit
`project.yml` and regenerate.

```bash
xcodegen generate          # after editing project.yml or adding/removing files

# Compile-check in the Simulator (no signing)
xcodebuild build -project TertiaryHRMSiOSApp.xcodeproj -scheme TertiaryHRMSiOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/hrms_dd CODE_SIGNING_ALLOWED=NO

# Install on a connected iPhone.
# NOTE: this Mac has no Xcode account, so automatic signing fails ("No Accounts").
# Sideload via the ASC API instead: create an IOS_APP_DEVELOPMENT profile
# (bundle com.tertiaryinfotech.hrportal + the local "Apple Development" cert + the device),
# install it to ~/Library/MobileDevice/Provisioning Profiles/, build with MANUAL signing
# (PROVISIONING_PROFILE_SPECIFIER + CODE_SIGN_IDENTITY), and `xcrun devicectl device install app`.
# Use the device's UUID (`-destination 'id=<UUID>'`); `name=` does not resolve here.
xcrun devicectl list devices
```

New Swift files under `TertiaryHRMSiOSApp/` are picked up automatically on the next
`xcodegen generate`. No third-party dependencies — system frameworks only (SwiftUI, Foundation/
URLSession, PDFKit).

A screenshot/preview seed is available via launch arguments (`-uiPreview`, `-uiPreviewLogin
password|otp`, `-uiPreviewTab 0-4`, `-uiPreviewOpen leave|trainers|trainer|applyleave|payslips|…`,
`-uiPreviewLeave al-excess|intern-mc|npl`, `-uiPreviewIntern`) — used only for App Store capture; no fake data ships to real installs
(`AuthViewModel.bootstrap()`).

## Architecture

Single-coordinator MVVM around `AuthViewModel` (`@MainActor`). Networking is two actors:
`AuthService` (NextAuth sign-in) and `HRMSAPI` (typed reads + writes — apply-leave, submit-claim,
clock, approve/reject, upload, notifications, profile update, change password, public holidays —
plus PDF download), both riding the shared cookie store. `RootView` routes loading → `LoginView`
→ `MainTabView` (Home / Leave / Calendar / Team / More). Reusable TIA premium-blue controls live in `Views/Components/`.

**Security model — the app holds NO secrets.** It ships zero API keys/credentials; every call
rides the user's own NextAuth session cookie, and all RBAC/validation stays on the server (the
single source of truth). **Never** put a key (Coolify, DB, admin, etc.) in `Info.plist` or the
bundle — it is extractable from any App Store download. Approval access = role ∈ {ADMIN, HR,
MANAGER} (`hasAdminAccess` in the web repo `src/lib/utils.ts`), enforced server-side; the client
merely hides the UI behind `summary.isAdmin`.

## App Store submission

Bundle id **`com.tertiaryinfotech.hrportal`** → replaces the existing App Store record
**“Tertiary HRMS”** (ASC app `6759821144`; store name set to **TIA HRMS** with v1.14). Submission is driven by the bundled
`app-store-submission` skill (`.claude/skills/`) and `scripts/asc_submit.py`; per-app values live in
the gitignored `.env`. The app requires login, so App Review needs a **demo account** in the review
notes. `Support/PrivacyInfo.xcprivacy` declares Email (App Functionality, not tracking) only.

## Conventions

Follow the bundled `mobile-ios-design` skill: Apple HIG, SF Symbols, large typography, ≥44pt touch
targets. One light premium-blue theme (`.preferredColorScheme(.light)`); colours only from `Theme`.
Keep screens neat: group with `CollapsibleSection`, list admin records as one line (`OneLineTable`) with the
detail in a sheet (`RecordSheet`), put filters in a `Menu` rather than rows of chips. The tab bar stays at five
tabs (HIG maximum), so the house **Feedback** + **About** screens live in More → Help.
Tests: `TertiaryHRMSiOSAppTests` (unit) and `TertiaryHRMSiOSAppUITests` (UI on `-uiPreview` data; set
`TEST_RUNNER_SCREENSHOT_DIR=<dir>` to save screenshots). Extra capture flags: `-uiPreviewFlag team|requests`,
`-uiPreviewQuery <text>`, `-uiPreviewOpen timesheet|mytimesheet|timeoff|feedback|about`.
