# Lab 3: Off-boarding Detection and Consent Auditing with PowerShell

**Built with:** Microsoft Graph PowerShell SDK · Microsoft Graph API · PowerShell 7

Lab 2 ended with a problem I couldn't answer from the portal. A termination reported success while the access was still there. If that can happen once, how would anybody ever know it happened again?

The portal shows you one user at a time. Answering an auditor takes a query.

## What I built

A PowerShell script that checks every terminated identity against the three places access actually lives: group memberships, licenses, and access package assignments. It exports to CSV so the output can go to an auditor as evidence.

## What I found

**The obvious check is the wrong check.** "Terminated but still enabled" is what almost everyone writes, and it would have returned zero rows during the actual Lab 2 failure, because that account *was* disabled. Disabling doesn't remove entitlements. You have to look at what someone still holds, not whether they can sign in.

**Asking for read-only doesn't get you read-only.** I connected with six read scopes and got a session with ten, including tenant-wide write on every user in the directory. The token carries whatever the application has already been consented for, not what I asked for today. Every piece of least-privilege advice I'd read treats that scope parameter as a limit. It's a request.

**I revoked the standing grant.** Ten permissions down to nine, and the next write session triggered a real consent prompt instead of connecting silently. Same argument PIM makes for people, applied to an application.

**A missing permission looks exactly like a clean result.** Graph returns the termination date as empty when you lack the scope to read it, not as access denied. A report built on that would show zero terminated users and look perfect. I made the script hard-stop instead of producing a report it isn't allowed to produce correctly.

**I corrected something I'd already published.** I had concluded the platform truncates a timestamp. Testing a second write path proved the platform keeps the full value and one workflow task was doing the truncating. Narrower, more useful, and I left the original reasoning visible rather than quietly editing it.

## Screenshots

| | |
|---|---|
| ![Terminated user still entitled](screenshots/04-terminated-user-still-holds-group-and-two-paid-licenses.png) | First real run. A terminated identity, still enabled, two days past its leave date, holding a group and two paid licenses. A groups-only check would have missed the licenses. |
| ![Before and after](screenshots/03-connect-lab-before-and-after-revoke.png) | Same command, same account, minutes apart. READ-WRITE with 10 scopes, then READ-ONLY with 9. |
| ![Standing consent](screenshots/01-graph-cli-admin-consent-includes-user-readwrite-all.png) | The root cause. Ten delegated permissions on the shared Graph application, every row granted through admin consent, including one I never asked for. |
| ![After revoke](screenshots/02-after-revoke-nine-permissions-read-only.png) | Ten permissions down to nine, every remaining entry a read or sign-in scope. |
