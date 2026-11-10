# Changelog

## [1.15] — 2026-11-11 (build 27 uploaded; build 25 was submitted to App Review first)
- Push notifications (APNs): interns get missed clock-in / clock-out and timesheet reminders; admins get new leave, MC, time-off and expense-claim requests. The token is registered after sign-in (`POST /api/mobile/push-token`) and removed on sign-out; a tapped push opens the matching screen (Approvals, Clock In/Out, Leave, Expenses, Time Off, Timesheet). The Notifications list now shows every notification addressed to you, and tapping one opens its screen.
- Trainers (More → My work): a read-only trainer contact list for every staff member and intern (search; tap for email, call and WhatsApp). Trainer Management stays under Manage for Trainer Admins.
- Trainer Management: long certificate names show as short codes (ACLP, ACTA, DACE, DDDLP; "ALCP"/"DDDPL" typos fixed), chips never push the row off-screen, and an IBF badge marks the IBF Fit declaration. The profile's Accreditation card lists only what the trainer holds, with readable labels.
- Calendar in the Planner app's design: Month / List toggle; Mon-first edge-to-edge grid with greyed adjacent-month days; tinted chips (You blue, Colleague amber) and "+N"; today as a premium-blue circle; public holidays grey and named; tap a day for its leave and holiday below the grid; List shows upcoming leave and holidays by day; Everyone / Only me in the filter menu.
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
