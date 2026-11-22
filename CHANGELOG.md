# Changelog

## [1.21] — 2026-11-22 (build 41 replaces build 40 in App Review; 1.20 build 38 is live)
### Build 41
- Team tab for admins only; staff and interns get an **SOP** tab with the procedures shown natively (`GET /api/mobile/sops`); More → SOP opens the same screen instead of the website (which failed with a Google 400 in the browser).

Status (22 Nov 2026, 15:00 SGT): build 40 uploaded, VALID, submitted: WAITING_FOR_REVIEW. Android 1.21 (34) released to the Play production track the same day.
**What's New (user-facing):**
> The app is now called TIA HRMS at the top of every screen. Accountants can tap Income, Expenses, Bank statements and Bank reconciliation on Home to see the details: every bank line for the month with search, every statement import, and the reconciliation lines still to review. Staff and interns have a new SOP tab with the company's procedures. Trainer Admins can search trainers, skills and certifications straight from Home, and switch between My view and Trainer Admin right under their name. The staff list shows each person's department, full time or part time, and email. Notifications now list only what is still relevant: a request disappears once it is decided and old notices are cleared. Leave & MC tiles say what they count, and Annual leave is spelled out.

- Finance details (`FinanceViews.swift`, `FinanceModels.swift`) over the new `/api/mobile/finance/transactions` and `/api/mobile/finance/statements` and the web's reconciliation routes.
- `TrainerHomeSearch` on the Trainer Admin Home; View As row under the name.
- View As role previews for angch@ only; Trainer Admins keep My view / Trainer Admin.
- Team rows: department, employment pill, email. Leave & MC tile labels from build 39.
- Server side (web f87e76d): company-email login for staff, named elevated roles, relevant notifications, per-role alerts.

## [1.19] — 2026-11-20 (build 35; 1.18 build 34 was in App Review, so this is the next version)
Status (21 Nov 2026, 00:20 SGT): build 35 uploaded and VALID in App Store Connect. 1.18 build 34 is IN_REVIEW, so the 1.19 version cannot be created yet (ASC 409 "cannot create a new version of the App in the current state"); the in-review submission was not cancelled. Once 1.18 leaves review: create version 1.19, set What's New, then `submit_for_review.py --version 1.19 --build 35`.

**What's New (user-facing):**
> Accountants now clock in and out like interns: Time In/Out is in More under the new Attendance heading, the Timesheet sits next to Off In Lieu, and a missed clock-in reminder opens the clock. Trainer Management is now called Trainer Admin, as on the HRMS website. Trainer Admins can switch More > View As to a new Trainer Admin view that shows only the trainer counts, the trainer directory, the calendar and their profile.

- New `LeaveRules.mustClockIn(roles:)` / `auth.mustClockIn`, the client mirror of the server rule (interns, and accountants without ADMIN / HR / MANAGER).
- More: the "Intern" group is now **Attendance** and also shows for accountants who must clock in. Those accountants get **Timesheet** (their days and hours) and keep **Off In Lieu**; interns keep Timesheet only; everyone else is unchanged.
- Push and in-app notification links: "/timesheet" opens the user's own Timesheet for anyone who must clock in (was interns only); "/attendance" still opens the clock for everyone.
- "Trainer Management" renamed **Trainer Admin** (More → Manage link, Home section title), matching the web app.
- **Trainer Admin view** (web View As "trainer", 20 Nov 2026), for `canManageTrainers` holders only: a **View As** control (My view / Trainer Admin) at the top of More, saved on the device (`hrms_view_as`), reset to My view on sign-out and when the TRAINER_ADMIN capability is lost. In the Trainer Admin view the tabs are Home, Trainers, Calendar and More (Leave and Team hidden); Home is the "Trainer Admin" heading, the three trainer tiles and "Open trainer directory"; More is View As, My Stuff (My Profile, Calendar), People (Trainer Admin), Help and Sign out. Switching to it opens the Trainers tab; switching back opens Home. Push links work in either view (Leave / Team links open as a sheet while those tabs are hidden). Checked in light and dark.
- No API change; unit tests for the rule, the timesheet / attendance links and the View As fallback; UI test `testTrainerAdminViewAs`.

## [1.18] — 2026-11-20 (build 33; 1.17 build 32 was approved and released the same day)
### Build 34: calendar colours, time off and off days, Work Schedule, role tiles (replaces build 33 in App Review)
**What's New (user-facing):**
> The Calendar is now colour-coded, like the HRMS website: annual leave 🏖️, medical leave 🤒, no-pay leave 💸, other leave 📋 and time off ⏰ each have their own colour, and public holidays carry an emoji. Your approved time off and Off Days now show on the calendar, and your off days are shaded. Managers also see everyone's birthdays 🎂, and when they pick a person they see that person's leave and time-off totals for the month. My Profile has a new Work Schedule card with your working hours, working days and off days. Home shows your leave summary, the same figures as the approval emails. No Pay Leave is now a flat 14 days a year.

- Calendar: each leave chip and card takes its category colour (`entries[].category`, legend `categories` of `GET /api/mobile/team-calendar`, with the web table built in as a fallback) and the category emoji in front. A colleague's leave whose type is hidden keeps the neutral amber with no emoji. Holiday titles arrive with their emoji. The legend lists the categories shown, "Colleague" for hidden types and "Off day" when shading is on.
- Calendar: approved time off and Off Days (`timeOff`): "Time off 2:00 PM – 4:00 PM" or an all-day "Off Day", with the person's name for approvers. They follow Everyone / Only me and the person filter; the person list counts leave and time off (as the web), now labelled "Leave & time off for".
- Calendar (approvers): birthdays (`birthdays`) as "🎂 NAME birthday"; a picked person shows only theirs; Only me hides them.
- Calendar: off days shaded in the holiday grey when one schedule applies: the staff / intern viewer's `ownWorkdays`, or the person an approver picked (`people[].workdays`; Mon–Fri when empty); approved full-day Off Days too. Nothing is shaded on Everyone.
- Calendar (approvers, person picked): month totals: Annual / Medical / No Pay Leave in days, Other Leave when above 0, Time Off in hours plus off days. A port of the web `personMonthSummary` (leave across a month end split by working days, public holidays excluded).
- My Profile: **Work Schedule** card (title, department, working hours, working days, off days) from the new `/api/mobile/profile` fields; hidden on a server without them.
- Home: staff and interns see the server's `leaveSummary` tiles (paid leave taken, annual leave balance, MC taken, no-pay leave taken, with hints) instead of the locally computed AL / MC tiles; accountants get Pending expense claims, Income and Expenses for the month (`financeKpis`); Trainer Admins get Trainers / ACLP / Non-ACLP tiles (`trainerKpis`) that open the Trainers screen on that choice. Existing tiles stay when the fields are absent.
- No Pay Leave: the text now says a flat 14 days a year (was "21 days, prorated"); "Cap to date" became "Yearly cap". The figures still come from the server.
- iPhone Calendar sync: holiday events are keyed by date, so the new emoji titles update the existing events in place (unit-tested); birthdays are not synced.
- Every new field is optional and read leniently: an older server, or one unreadable new field, hides only that feature.

### Build 33: parity with the web changes of 20 Nov
- Calendar (approvers): **Leave shown for** now picks Everyone or one person, replacing All / Staff / Interns. The list is every active staff member and intern, grouped Staff then Interns, each with their number of leave entries; people who have left are not listed (their leave still shows under Everyone). Public holidays always show. Data: the new `people` field of `GET /api/mobile/team-calendar`; on a server without it the list is built from the leave entries.
- Analytics: new **Workforce breakdown** at the end of the screen. Three donuts (gender, age group, ethnic group) of active people with counts and percentages, and a Staff / Interns / All control (Staff first). A note says when ethnic group is not recorded. Data: the new `breakdown` field of `GET /api/mobile/analytics`; the section is hidden without it.
- Trainer Management: three tiles on top (Total, ACLP and Non-ACLP trainers; applicants are not counted) and an **ACLP / Non-ACLP / All** control with the same counts. The screen opens on ACLP trainers, sorted A to Z by name. A tile sets the same choice and clears the other filters; the active one is outlined.
- Team (approvers): staff and interns are two lists with a **Staff / Interns** control and counts (Staff first). Data: the new `intern` field of `GET /api/mobile/employees`; without it the single list stays.
- Home (approvers): the two pending tiles became three, as on the web dashboard: **Full-time staff**, **Interns** and **Pending approvals** (leave, MC and claims). Staff and Interns open those lists; the counts come from Analytics and the two tiles are left out if it cannot be loaded.
- Every new server field is optional in the app, so this build also works against a server that does not send them yet.

### Build 32 (replaced build 31 in App Review; resubmitted, WAITING_FOR_REVIEW)
- New **Analytics** screen for approvers (Home → Analytics, More → Manage → Analytics): the last 12 months of bank revenue and expenses, leave and MC per person, and headcount, the same data as the web Analytics page (`GET /api/mobile/analytics`). Filters: 3 / 6 / 12 months, All / Staff / Interns, a person, and leave type. Tap a category to leave it out of the totals, tap a person to see only their leave, tap a month for its figures. The tiles use the same filtered numbers as the charts.
- Calendar (approvers): an **All / Staff / Interns** control shows whose leave appears. Public holidays always show. The control appears only when the server marks each leave entry with its group.
- Notifications: the server now also sends a push when an expense claim is approved or rejected, and when a leave, MC or time-off decision is made from an emailed link. They open Expenses, Leave and Time Off (no app change was needed; covered by a test).
- Build 31 (19 Nov) held the Appearance changes below and was withdrawn from review for this build.
- New **Appearance** setting in My Profile: Light, Dark or System. System follows the iPhone's setting and is the default; the choice is saved on the device. The accounts angch@ and tansc@ start on Light.
- Dark appearance for every screen (near-black page, slate cards, near-white text), matching the web app's dark theme. Light is unchanged.
- Clock in / out button text is white on its colour fill.

## [1.16] — 2026-11-13 (build 30; build 29 lacked the summary and calendar parts)
- Interns: new **Off Day** option in Request Time Off — a full day off with no times to pick. Once approved, no clock-in or clock-out is expected that day and no missed clock-in reminder is sent. Regular weekly off days (the days not ticked in the intern's Workdays) never needed one.
- Time Off lists and Approvals show an Off Day as "Full day" instead of times and hours.
- Leave Summary shows an Off Day as "Full day · Off Day"; iPhone Calendar sync adds an approved Off Day as an all-day "Off Day" event.

## [1.15] — 2026-11-11 (build 28 uploaded; build 25 was submitted to App Review first)
- Push notifications (APNs): interns get missed clock-in / clock-out and timesheet reminders; admins get new leave, MC, time-off and expense-claim requests. The token is registered after sign-in (`POST /api/mobile/push-token`) and removed on sign-out; a tapped push opens the matching screen (Approvals, Clock In/Out, Leave, Expenses, Time Off, Timesheet). The Notifications list now shows every notification addressed to you, and tapping one opens its screen.
- Trainers (More → My work): a read-only trainer contact list for every staff member and intern (search; tap for email, call and WhatsApp). Trainer Management stays under Manage for Trainer Admins.
- Trainer Management: long certificate names show as short codes (ACLP, ACTA, DACE, DDDLP; "ALCP"/"DDDPL" typos fixed), chips never push the row off-screen, and an IBF badge marks the IBF Fit declaration. The profile's Accreditation card lists only what the trainer holds, with readable labels.
- Calendar in the Planner app's design: Month / List toggle; Mon-first edge-to-edge grid with greyed adjacent-month days; tinted chips (You blue, Colleague amber) and "+N"; today as a premium-blue circle; public holidays grey and named; tap a day for its leave and holiday below the grid; List shows upcoming leave and holidays by day; Everyone / Only me in the filter menu.
- iPhone Calendar sync (More → Help → iPhone Calendar sync): one-way copy of your approved leave & MC, approved time off, optionally public holidays and (admins) team leave into the calendars you tick. Events carry an "HRMS id:" marker line; only those are updated or removed. Runs at sign-in, on returning to the app, after you apply or approve, on calendar changes and every 2 minutes while open.
- Calendar header: refresh button and "Synced h:mm" caption; screens reload when the app returns to the foreground.
- More menu: Applications (MC, Leave, Time Off, Expense Claims, Off In Lieu / intern Timesheet), Staff (Calendar, Payslips, My Profile, Trainers), Intern (Time In/Out — interns and admins), Manage, Help. MC opens the leave form on Medical Leave.
- New premium-blue app icon (saturated royal blue #0E4FD0→#0138A5→#001C68, matching the TC LMS SG app; master in tia-hrms-brand/icon-1024.png).
- White initials on the premium-blue avatars (Team, Profile) and white text on selected royal-blue buttons.
- Build 22 (same version, without push) was uploaded earlier and superseded; build 23 had everything except the calendar change; build 24 (no new icon) was never finished uploading.

## [1.14] — 2026-11-10 (build 21, replaced build 20 in App Review; WAITING_FOR_REVIEW)
- One light premium-blue theme everywhere (white cards on a pale blue surface, navy text, royal-blue actions, gold only on accreditation badges). Dark mode is gone: the app is forced light, like the web app.
- Approvals: pending leave / MC and hourly time off are one-line tables (name, status, type, dates, days, applied, reason). Tap a row for the full reason and Approve / Reject. Sections collapse; time-off requests can now be approved in the app.
- Time Off (approvers): new Mine / Team switch. Team lists everyone's requests as one-line rows with a status filter.
- Leave & MC: new People / Requests switch. Requests lists every leave and MC request of the month on one line each, with a leave-type filter.
- Trainer Management: search suggests skills and certifications with trainer counts, and a picked suggestion becomes a removable filter. Accreditation (ACLP / ACTA / DACE / DDDLP / Finance / IBF Fit) and Trainers / Applicants sit in one Filters menu. Rows are compact (name, badges, matching skill first) with call / WhatsApp / email / copy. The profile has Call, WhatsApp, Email and Copy buttons; long sections collapse. The NRIC stays masked until you tap Show.
- Timesheet: Intern Attendance is merged into one admin Timesheet (missing-punch and Off In Lieu approvals, then interns' days and hours per month; tap an intern for each day). Interns see their own Timesheet; other staff see Off In Lieu instead of Timesheet.
- More menu grouped into My work / Manage / Help, with new Feedback (WhatsApp) and About screens.

### Also in 1.14 (first submitted 2026-11-09 as build 20, withdrawn before review)
- The app is now called TIA HRMS, with a new premium-blue look.
- Apply for leave: when annual leave would exceed your balance, the app explains why and offers "Apply as No Pay Leave instead" for the same dates.
- Interns: picking medical leave switches the form to No Pay Leave, with the reason "Sick leave (MC)" and your medical certificate still attached.
- Leave balances show your No Pay Leave cap and the days you have left; No Pay Leave cap errors are explained.
- Trainer Admins: new Trainers directory (More menu) to search trainers by name, accreditation (ACLP, ACTA, DACE, DDDLP), finance background and IBF Fit declaration, and open each trainer's full profile.
- Fixed leave balance cards splitting into two boxes.

## [1.13] — submitted for App Review 2026-11-06 (build 19)
- Apply for leave: the working-days count now skips Singapore public holidays.
- Apply for leave: half-day options now show only for Annual Leave, because other leave types, including No Pay Leave, are recorded as full days.

## [1.12] — submitted for App Review 2026-11-02 (build 18)
- Admins: on a team member's records, tap the Days clocked, MC days or Leave days tile to open that person's full clock in/out, MC or leave history.

## [1.11] — submitted for App Review 2026-10-21 (build 17)
- Admins: new Leave & MC Summary screen (More menu) shows every staff member's and intern's MC and leave for the month — approved vs pending days, intern time-off hours, and each person's AL / MC balances.
- Includes the 1.10 change: clock-in history shows hours so far, or "No clock-out" for a missed clock-out.

## [1.8] — submitted for App Review 2026-10-08 (build 14)
- Clock In / Out now shows your daily check-in and check-out history for any month, with total hours and days worked.
- Admins: new Intern Attendance screen (More menu) lists every intern's days worked and total hours for the month, with each intern's daily history.

## [1.7]
- Fixed the Calendar tab failing with a 404 by sending the selected year as a real URL query parameter.

## [1.5]
- New Timesheet: log weekend and public-holiday work hours each week and earn Off-In-Lieu days after approval.
- New Time Off: submit hourly time-off requests (exams, emergencies and more) and track their approval status.
- The punch screen is now called Clock In / Out in the More menu.

## [1.4]
- Web clock in/out parity and shared punch history.
