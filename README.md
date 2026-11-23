<div align="center">

<img src="TertiaryHRMSiOSApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="120" alt="TIA HRMS icon" />

# TIA HRMS — iOS

**Native SwiftUI client for the Tertiary Infotech Academy HR Management System.**

A fully native iPhone app (no Capacitor, no WebView) that signs employees in and pulls their HR
data live from the company's HRMS backend on Coolify.

<a href="https://apps.apple.com/sg/app/tertiary-hrms/id6759821144">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="48" />
</a>

![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-0A1F44?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-1D4ED8?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-3B82F6)
![Backend](https://img.shields.io/badge/backend-Next.js%20on%20Coolify-0A1F44)
![App Store](https://img.shields.io/badge/App%20Store-Live%20(Singapore)-0A1F44?logo=appstore)
![License](https://img.shields.io/badge/license-Proprietary-555)

</div>

## Screenshots

![TIA HRMS — dashboard](screenshot.png)

| Dashboard | Leave balances (No Pay Leave) | Apply as No Pay Leave | Team |
|---|---|---|---|
| ![](screenshots/01-dashboard.png) | ![](screenshots/02-leave.png) | ![](screenshots/03-apply-npl.png) | ![](screenshots/04-team.png) |

| Trainers (Trainer Admin) | Trainer profile | Payslips | More |
|---|---|---|---|
| ![](screenshots/05-trainers.png) | ![](screenshots/06-trainer-profile.png) | ![](screenshots/07-payslips.png) | ![](screenshots/08-more.png) |

## What it is

This is the App Store build of the Tertiary HRMS, rebuilt **natively in SwiftUI**. It is a thin,
secure client over the existing HRMS web backend — it holds no database of its own and enforces no
business rules locally; the server remains the single source of truth.

- **Backend:** the HRMS **Next.js 14** app deployed on **Coolify** at
  `https://hrms.tertiaryinfotech.com`, backed by PostgreSQL on the same Coolify host.
- **The iOS app pulls all data from that Coolify deployment over HTTPS** through the web app's
  authenticated API — it never touches the database directly.
- **Auth** reuses the web app's **NextAuth (Auth.js)** session: a standard
  `csrf → callback → session` flow, with the session cookie persisted so employees stay signed in.
  **Email + password**, **email one-time-code (OTP)** and **Google sign-in** are supported —
  the last via Apple's `ASWebAuthenticationSession` with an OAuth 2.0 PKCE flow (no third-party
  SDK), whose Google `id_token` the backend verifies before issuing the session.
- A small, **additive `/api/mobile/*`** namespace was added to the web backend to expose (as JSON)
  the same data the web pages render, plus the app's writes (receipt-photo claims, clock in/out).
  It changes no existing web behaviour; approver-only data (approvals, intern attendance, a
  colleague's records) is enforced server-side.

## Features

**Included** — the employee HR experience:

| Module | What you get |
|---|---|
| 🔐 **Sign-in** | One screen under the **Tertiary Infotech Academy** logo: a **@tertiaryinfotech.com** email gets **Continue with Google** (always Google's account chooser, listing every account on the phone) plus **Email me a sign-in code**; any other email (interns, part-time staff) gets the emailed code first; **Sign in with a password** is the last, small link. The code screen has **Back to sign in**. Personal email is allowed only for part-time staff and interns (enforced by the server); session persists across launches |
| 🧭 **Tabs per role** | Admins: Home · Leave · Calendar · Team · More. Staff and interns: Home · Leave · Calendar · **SOP** · More. Accountants: Home · **Income** · **Expenses** · More. Trainer Admin view: Home · Trainers · More |
| 🏠 **Home (per role)** | **Staff:** annual leave and MC left with **Apply for leave / Apply for MC**, own leave tiles. **Interns** (and accountants who must clock in): a **Clock in / out** card at the top. **Admins:** active staff and interns, Pending approvals and a **Waiting for approval** card (leave, MC, time off, claims, missed punches). **Accountants:** finance only: pending claims, income and expenses with credit / debit counts, bank statements, bank reconciliation, **each row opening its detail** (the month's bank credits or debits with search, every statement import, the latest reconciliation's lines to review). **Trainer Admins:** trainer counts and a **search** for trainers, skills and certifications. The Welcome card opens My Profile |
| 🗓️ **Leave** | Balances (including the **No Pay Leave** cap and days left), full request history, and **apply for leave** — with a **live working-days preview** (weekends & SG public holidays auto-excluded) and MC-photo attach for medical leave. Annual leave beyond the balance offers **Apply as No Pay Leave instead**; interns' MC goes in as No Pay Leave with the certificate attached |
| 👥 **Team** (admins) | Company directory, admins only; approvers see staff and interns as two lists (Staff / Interns with counts), each person with full name, department, **Full time / Part time** and email. Approvers tap a person for their **clock-in history** (every clock in/out, grouped by month), **MC history** and **leave history** — tapping the Days clocked / MC days / Leave days tiles opens each full history |
| 🧾 **Payslips** | Personal payslips with a native **PDFKit** viewer for the authenticated PDF |
| 💳 **Expenses** | Personal expense claims with status and approved totals, plus **submit a claim with a receipt photo** (camera or library) |
| 📅 **Calendar** | Planner-app layout: Month / List, Monday-first grid with adjacent-month days greyed, chips + "+N", today circled, every SG public holiday on a grey cell with its name, the selected day's agenda below; refresh button + "Synced h:mm". **Staff and interns see only their own leave, MC, No Pay Leave and time off plus the holidays** ("My leave and holidays"; enforced by the server since 22 Nov 2026). Admins get *Everyone / Only me* and **Leave shown for**: Everyone or one active staff member or intern (grouped, with leave counts). **Accountants** (Income tab in its place) and the **Trainer Admin view** have no calendar. |
| 📆 **iPhone Calendar sync** | One-way EventKit sync (like the Planner app) of your approved leave, MC and time off — optionally public holidays and, for admins, team leave — into the iPhone calendars you tick; runs at launch, on return, after applying/approving, on calendar changes and every 2 min; only touches events carrying its `HRMS id:` marker |
| ⏱️ **Clock In / Out** | One-tap **clock in / out** with a live elapsed timer and a monthly daily check-in/out history with total hours — an open punch shows **hours so far** today, or **"No clock-out"** for an earlier day |
| 🗂️ **Timesheet** (interns and accountants) | Interns and accountants who must clock in: their own days and hours per month (accountants keep Off In Lieu too). Approvers: one Timesheet screen — missing-punch and Off In Lieu approvals plus every intern's days worked + total hours per month, drilling into their daily history. Staff log weekend / PH work under **Off In Lieu** |
| 📇 **Trainer contacts** (everyone, More → People) | Trainer contact list for every staff member and intern: search, then email / call / WhatsApp — `GET /api/mobile/trainers/contacts` (no NRIC) |
| 🎓 **Trainers** (Trainer Admins, More → People) | Total / ACLP / Non-ACLP tiles and an ACLP / Non-ACLP / All control (opens on ACLP, A–Z by name); search with skill / certification suggestions (with counts) that become removable filter tokens; one Filters menu for ACLP / ACTA / DACE / DDDLP / Finance / IBF Fit and Trainers / Applicants; compact rows with the matching skill first and call / WhatsApp / email / copy; profiles with masked NRIC and collapsible sections — `GET /api/mobile/trainers` |
| 🩺 **Leave & MC Summary** (admin) | Every staff member's and intern's MC and leave for the month (approved vs pending, intern time-off hours), drilling into each person's requests and AL / MC balances — `GET /api/mobile/leave-summary` |
| 👁️ **View As** | Alfred only: preview the **Admin / Staff / Intern / Accountant / Trainer Admin** screens from Home or More (forms still act as you, clocking in is off while previewing). Trainer Admins (Deepa, Tan Soik Ching) get a **My view / Trainer Admin** switch under their name |
| 🔔 **Notifications** | In-app bell with unread badge, plus **push notifications** (APNs). Only relevant notices are listed: a request disappears once decided, only the latest roll-up of each kind, nothing older than 30 days. Admins: every new leave / MC / NPL, time-off and expense request; accountants: new claims, bank reconciliation and a daily **Finance to clear**; interns: missed clock-in / clock-out; staff: each approval decision. Tapping opens the right screen |
| ⬆️ **Force update** | The app checks the App Store version at launch and on return; an older app shows a blocking **Update required** screen (`/api/public/app-version`, and HTTP 426 from the server) |
| ☰ **More menu** | Mirrors the web sidebar for the current view: My Stuff · People · Processes (leave, time off, clock in/out, timesheet / Off In Lieu, approvals) · Accounting (web links: expense / income tracking, bank reconciliation, bank statements) · Finance (claims, payslips) · Documents (SOP) · System (Settings) · Help. Admins do not apply for leave; accountants have no leave, MC or time off |
| 📘 **SOP** | The company's Standard Operating Procedures in the app (search, grouped by area, numbered steps with who and when). Staff and interns have it as a tab in place of Team; everyone also reaches it from More |
| 🙋 **Profile** | Your full employee record, with **self-service edit** and **change password** |

**Excluded** — by product decision:

- Accounting **actions** (bank-statement import, recording in QuickBooks, running or reviewing a
  reconciliation) stay on the web; the app shows the figures and details read-only.
- Heavy **admin authoring** flows (creating employees, generating payroll, company settings, email
  templates) — these remain on the web; the dashboard surfaces approval counts only.

## Tech

- **Swift 5 / SwiftUI**, MVVM, single coordinator (`AuthViewModel`).
- Networking: two `actor`s — `AuthService` (NextAuth sign-in) and `HRMSAPI` (typed reads and
  writes — apply-leave, claims, clock, approvals, profile — plus PDF download) over a shared cookie store.
- **System frameworks only** — SwiftUI, Foundation/URLSession, PDFKit. No third-party dependencies.
- **XcodeGen** project generation (`project.yml`); the `.xcodeproj` is gitignored.
- iOS 16+, iPhone, portrait. **Appearance: Light, Dark or System** (My Profile → Appearance; default System, saved on the device). Light is the TIA premium-blue look (white cards on a pale blue surface, navy #0D1638 text, royal #2F5BE6 actions, gold #F5B83D as a sparing accent); Dark matches the web app's dark theme.

## Build

```bash
brew install xcodegen        # one-time
xcodegen generate

# Compile-check in the Simulator (no signing required)
xcodebuild build -project TertiaryHRMSiOSApp.xcodeproj -scheme TertiaryHRMSiOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/hrms_dd CODE_SIGNING_ALLOWED=NO

# Unit tests (leave-rule errors + trainer decoding)
xcodebuild test -project TertiaryHRMSiOSApp.xcodeproj -scheme TertiaryHRMSiOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' CODE_SIGNING_ALLOWED=NO

# Run on a connected iPhone
xcodebuild build -project TertiaryHRMSiOSApp.xcodeproj -scheme TertiaryHRMSiOSApp \
  -destination 'platform=iOS,name=<your iPhone>' -allowProvisioningUpdates
```

## Project layout

```
TertiaryHRMSiOSApp/
├─ project.yml                 # XcodeGen config (bundle com.tertiaryinfotech.hrportal)
├─ TertiaryHRMSiOSApp/
│  ├─ App/                     # @main entry
│  ├─ Theme/                   # TIA premium-blue palette + formatters
│  ├─ Models/                  # Codable models for the mobile API
│  ├─ Resources/               # Asset catalog (app icon, colours)
│  ├─ Services/                # AuthService (NextAuth), GoogleSignInService (OAuth+PKCE), HRMSAPI
│  ├─ ViewModels/              # AuthViewModel
│  ├─ Views/                   # Login + tabbed feature screens
│  └─ Support/                 # Info.plist, PrivacyInfo.xcprivacy
├─ scripts/                    # Premier Blue icon + screenshot framer
└─ .claude/skills/             # app-store-submission, ios-auto-release, mobile-ios-design, ipados-design-guidelines
```

## App Store

Bundle id `com.tertiaryinfotech.hrportal` → the existing **Tertiary HRMS** App Store record
(ASC app `6759821144`). **Status: v1.21 (build 48) is the released version; v1.22 (build 49 — Continue with Google always shows Google's account chooser) was submitted for review on 2026-11-23 and is WAITING_FOR_REVIEW:
[apps.apple.com/sg/app/tertiary-hrms/id6759821144](https://apps.apple.com/sg/app/tertiary-hrms/id6759821144).** Submission is automated via the bundled `app-store-submission` skill and
its bundled `asc_submit.py` (App Store Connect API); `ios-auto-release` wires up CI/CD for
future builds. Credentials live in a gitignored `.env`; the `.p8` key never enters the repo.

---

<div align="center">
Built for <b>Tertiary Infotech Academy Pte Ltd</b>.
</div>
