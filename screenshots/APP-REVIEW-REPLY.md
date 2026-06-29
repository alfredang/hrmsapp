# App Review Resubmission Notes

Latest rejection:

- Submission ID: `f6893c1a-f976-440c-b458-b8bdcc022c38`
- Review date: June 18, 2026
- Review devices: iPad Air 11-inch (M3) and iPhone 17 Pro Max
- Version reviewed: `1.0 (4)`
- Guidelines:
  - 3.2.0 Business - Other Business Model Issues
  - 2.1(a) Performance - App Completeness / Information Needed
- Issues:
  - Apple says the app is still intended for a specific business or organization but is configured for public App Store distribution.
  - Apple says not to resubmit until the Unlisted App Distribution request has an email outcome.
  - Apple could not verify all app features/account types from the provided demo access.

Actions completed on June 18, 2026:

1. Patched the existing App Review Notes in App Store Connect to explicitly state that this submission is intended for Unlisted App Distribution.
2. Explained that Tertiary HRMS is an employee resource app for a limited audience, including employee-owned devices that may not be managed through Apple Business Manager.
3. Explained that the app is not intended to be discoverable through App Store search, categories, charts, or recommendations.
4. Reconfirmed that access is restricted by provisioned employee credentials.
5. Canceled the rejected review submission and resubmitted version `1.0` build `4`.
6. Submitted the Apple Developer Support request for Unlisted App Distribution.
7. Added the Apple Developer Support case ID to App Review Notes, canceled the new unresolved submission, and resubmitted version `1.0` build `4` again.
8. Refreshed the backend App Review seed account so `appreview@tertiaryinfotech.com` has `ADMIN`, `HR`, `MANAGER`, and `STAFF` roles, one payslip, seeded leave/expense/calendar/timesheet/profile data, and visible pending approval counts.
9. Patched App Store Connect App Review Information:
   - `demoAccountRequired = true`
   - Demo username set to `appreview@tertiaryinfotech.com`
   - Demo password set in the structured password field
   - Notes updated to explain the full-access seeded account and to state that the app will not be resubmitted until the Unlisted App Distribution request receives an email outcome.

Apple Developer Support case:

- Case ID: `102918638261`

Current App Store Connect state:

- App: `6759821144` / Tertiary HRMS
- Version: `1.0`
- Build: `4`
- App Store version state: `REJECTED`
- Review submission state: `UNRESOLVED_ISSUES`

Review Notes currently sent:

```text
Distribution note for App Review: This submission is intended for Unlisted App Distribution. The Apple Developer Support case ID for the unlisted distribution request is 102918638261. We understand Apple's June 18, 2026 review note and will not resubmit this app version until we receive email confirmation regarding the outcome of that unlisted distribution request.

Tertiary HRMS is an employee resource app for a limited audience, including employees using employee-owned devices that may not be managed through Apple Business Manager. It is not intended to be discoverable in App Store search, categories, charts, or recommendations. Access is restricted by provisioned employee credentials, so anyone without an employee account cannot use the app.

Demo account for review: The structured demo account fields below are enabled. Sign in on the first screen with email appreview@tertiaryinfotech.com and password AppReview2026!. Tap Continue after entering the email, then enter the password. The app also supports a one-time email passcode, but please use the email + password above since the passcode is emailed to an inbox you cannot access.

This review account is seeded with ADMIN, HR, MANAGER, and STAFF roles so App Review can verify role-gated mobile functionality from one login. It includes pre-populated Dashboard approval counts, Leave balances and history, Team directory, one Payslip with PDF download, one Expense claim, Calendar events, Timesheet entries, and Profile data. No special hardware or permissions are required.
```

Remaining follow-up:

Do not resubmit until Apple emails the outcome for Developer Support case `102918638261`. If approved for Unlisted App Distribution, resubmit the same app version after confirming the App Review Information still contains the structured demo credentials.
