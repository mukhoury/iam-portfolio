# Lab 4: Hybrid Identity and Directory Synchronization

**Built with:** Windows Server 2025 · Active Directory Domain Services · Microsoft Entra Connect Sync · Microsoft Entra ID P2 · PowerShell

My first three labs were cloud-only. Every user was created in Entra ID, so Entra was the source of truth. Most companies don't work that way. They have an on-premises Active Directory that has been there for years and a cloud directory that showed up later, and the on-premises one is usually in charge.

I wanted to build that setup myself and then break it on purpose to see what the cloud can and can't tell you.

## What I built

An Active Directory forest on a Windows Server domain controller, synced into my Entra ID tenant with Entra Connect Sync.

I used a `.local` domain name on purpose, because that's what a lot of real companies are stuck with and it forces you to deal with the UPN problem instead of avoiding it. I ran the custom install instead of Express so I had to actually choose the sign-in method and the sync scope rather than letting the wizard decide.

I scoped the sync to one organizational unit and deliberately left two service accounts outside it, so there would be something real to go looking for later.

Fifteen accounts on-premises. Thirteen made it to the cloud.

## What I found

**Disabling an account doesn't remove access.** I disabled a user in Active Directory the way a help desk would on a termination ticket. The cloud account went to Disabled. He also kept his dynamic group membership and both of his licenses, because the group rule checks his department and nobody clears that when someone leaves. He couldn't sign in, and that was the entire effect.

**The second step of a normal off-boarding deletes the account.** After disabling him I moved him to a Disabled Users folder, which is the other thing everyone does. That folder was outside the sync scope, so Entra Connect read him as gone and deleted the cloud identity. The tenant went from 25 users to 24. No warning, no confirmation. The step that looks like filing paperwork is the destructive one.

**A membership count can't tell you access changed.** On a different user I changed one attribute, department, from Sales to Finance. Her group membership count read 1 before and 1 after. What actually happened is one group dropped her in the same operation another group picked her up. Everything she had access to was replaced and the number I was watching never moved. I only proved it was one operation because both audit events share the same correlation ID.

**Nothing in the cloud can tell you what didn't sync.** Those two service accounts I excluded don't exist in Entra, so there's no row to filter on and no error to find. The provisioning error report works fine and returns zero, because leaving something out of scope isn't a failure. Entra says 13 users synced and has no way to tell you 13 out of what. I had to log into the domain controller to get that number.

**Two Microsoft consoles gave me opposite answers.** The Entra Connect page said sync status Enabled with no warning while my domain controller had been powered off overnight. Connect Health said Error on the same server after it came back and was syncing fine. Neither one was reporting on what it looked like it was reporting on.

## Where I'd go next

The fix for the disable problem is to clear the attributes that drive group membership, not just the sign-in flag. That's the same conclusion I reached in Lab 2 from a completely different direction, which is probably the actual lesson.

For the sync gap, the only thing that works is comparing both directories on a schedule and alerting on the difference, because no single console can see both sides.

## Screenshots

| | |
|---|---|
| ![Ground truth](screenshots/149-full-ad-reconciliation-13-employees-2-service-accounts-0-disabled.png) | Read straight from the domain controller. 13 employees, 2 service accounts, 0 in the disabled container. Fifteen exist, thirteen reached the cloud. |
| ![Disabled but entitled](screenshots/164-6c2-FINDING-disabled-user-still-in-sales-dynamic-group-same-guid.png) | A terminated user, disabled on both sides, still holding the same dynamic group membership as before. |
| ![Deleted, not disabled](screenshots/171-6c3-FINDING-victor-ramos-0-users-found-deleted-not-disabled.png) | Zero users found. Moving the account to an out-of-scope folder deleted the cloud identity outright. |
| ![Opposite verdicts](screenshots/152-connect-health-says-error-1-alert-while-connect-blade-says-enabled.png) | Connect Health reporting Error on the same server the Connect Sync page called Enabled. |
