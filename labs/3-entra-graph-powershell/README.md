# Lab 3: Off-boarding Detection and Consent Auditing with PowerShell

**Built with:** Microsoft Graph PowerShell SDK · Microsoft Graph API · PowerShell 7

Lab 2 ended with a problem I couldn't answer from the portal. A termination reported success while the access was still there. If that can happen once, how would anybody ever know it happened again?

The portal shows you one user at a time. Answering an auditor takes a query.

## The risk

An off-boarding failure that nobody detects is indistinguishable from an off-boarding that worked. Both look like a closed ticket.

The second risk showed up while I was building the detection: if the person running the check has more permission than they think, or less, the report is wrong in a way that looks fine either way. Too much permission is an exposure. Too little produces a clean-looking report that's actually empty.

## What I built

A PowerShell script that checks every terminated identity against the three places access actually lives: group memberships, licenses, and access package assignments. It exports to CSV so the output can go to an auditor as evidence.

All users in this lab are fictional and the tenant was built for this project. Nothing here is production data.

## What I found

**The obvious check is the wrong check.** "Terminated but still enabled" is what almost everyone writes, and it would have returned zero rows during the actual Lab 2 failure, because that account *was* disabled. Disabling doesn't remove entitlements. You have to look at what someone still holds, not whether they can sign in.

**Asking for read-only doesn't get you read-only.** I connected with six read scopes and got a session with ten, including tenant-wide write on every user in the directory. The token carries whatever the application has already been consented for, not what I asked for today. Every piece of least-privilege advice I'd read treats that scope parameter as a limit. It's a request.

**I revoked the standing grant.** Ten permissions down to nine, and the next write session triggered a real consent prompt instead of connecting silently. Same argument PIM makes for people, applied to an application.

**A missing permission looks exactly like a clean result.** Graph returns the termination date as empty when you lack the scope to read it, not as access denied. A report built on that would show zero terminated users and look perfect. I made the script hard-stop instead of producing a report it isn't allowed to produce correctly.

**I corrected something I'd already published.** I had concluded the platform truncates a timestamp. Testing a second write path proved the platform keeps the full value and one workflow task was doing the truncating. Narrower, more useful, and I left the original reasoning visible rather than quietly editing it.

## What I'd recommend

Check entitlements, not account state. "Terminated but still enabled" misses the exact failure it's meant to catch.

Audit what your tooling actually holds rather than what it requested. A standing admin consent grant on a shared application quietly governs every session anyone opens with it, and revoking it converts permanent write access into consent requested at the moment of need.

Any script that produces audit evidence should assert its own permissions and refuse to run rather than emit an incomplete report.

## What I'd do differently in a real environment

This would run on a schedule against a service principal with certificate authentication, not interactively from a laptop, and the output would go somewhere with retention rather than a local CSV.

I'd also reconcile against the HR system rather than the directory's own leave date, since the directory only knows what somebody remembered to write into it.

## Screenshots

| | |
|---|---|
| ![Terminated user still entitled](screenshots/04-terminated-user-still-holds-group-and-two-paid-licenses.png) | First real run. A terminated identity, still enabled, two days past its leave date, holding a group and two paid licenses. A groups-only check would have missed the licenses. |
| ![Before and after](screenshots/03-connect-lab-before-and-after-revoke.png) | Same command, same account, minutes apart. READ-WRITE with 10 scopes, then READ-ONLY with 9. |
| ![Standing consent](screenshots/01-graph-cli-admin-consent-includes-user-readwrite-all.png) | The root cause. Ten delegated permissions on the shared Graph application, every row granted through admin consent, including one I never asked for. |
| ![After revoke](screenshots/02-after-revoke-nine-permissions-read-only.png) | Ten permissions down to nine, every remaining entry a read or sign-in scope. |
