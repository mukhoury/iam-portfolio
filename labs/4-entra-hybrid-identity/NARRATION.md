# Narration Spine — Lab 4, Hybrid Identity

Talking points for the recorded walkthrough and for interview answers. **Not a
script.** Read it enough times that the ideas are yours, then say them your own
way on camera. Reading this aloud will sound like reading this aloud.

The rule for every phase: **say what problem this solves before you say what
button you clicked.** Anyone can narrate a wizard. The thing being tested is
whether you know what breaks when it's wrong.

---

## The whole lab in one idea

A company ends up with two directories: one on-premises that has been there for
twenty years, and one in the cloud that showed up with Microsoft 365. Neither one
is going away.

The problem is not technical. The problem is that **a person is one person, but
the systems think they're two.** Two accounts, two passwords, two places to
revoke access, two places for something to be missed.

Everything in this lab exists to close that gap without opening a new one. And
the "without opening a new one" half is where most of the interesting failures
live, because the act of connecting two trusted systems creates a path that did
not exist before.

**If you only say one thing on camera, say that.**

---

## Phase 1 — a domain controller in the cloud

**Macro point:** where identity infrastructure runs has changed. What it does
has not. And the moment it runs inside a cloud subscription, that subscription's
permissions quietly become identity permissions.

Worth saying:

- Active Directory did not stop mattering because companies moved to the cloud.
  A very large share of enterprises still authenticate against it every morning.
- Running it as a cloud virtual machine is normal now, and it introduces a
  question nobody asked in the datacenter era: who can reach the *host*, not just
  who can reach the directory.
- The two hardening steps were not busywork. RDP was open to the entire internet
  the moment the machine existed, and a domain controller has to hold a fixed
  address because every other machine finds it by that address.

**The strongest line, and it is backed by something that actually happened in
this lab:** I created twelve user accounts in this domain from a laptop, with no
domain credentials, no remote session, and no Windows password. All I had was
Contributor rights on the Azure resource. Active Directory permissions never
entered the picture, because the code did not authenticate to Active Directory,
it ran underneath it.

So if you audit who is in Domain Admins but not who holds Contributor on the
subscription hosting the domain controller, you have audited half the problem.

---

## Phase 2 — what a domain controller actually is

**Macro point:** it is the thing that answers "is this person who they say they
are," and everything else in the company trusts that answer without checking.

Worth saying:

- Installing the software and promoting the server are two different operations.
  After the install there is still no directory. People conflate these constantly.
- The forest and domain names are effectively permanent. Renaming a forest is
  painful enough that most organizations never do it, which is why so many are
  still running on names chosen in 2005.
- Time is load-bearing. Kerberos rejects tickets when two clocks disagree by more
  than five minutes, on purpose, because that is what stops a captured ticket from
  being replayed later. A domain controller with a drifting clock stops
  authenticating people.
- `ntds.dit` is one file holding every user, every group, and every password hash
  in the domain. When a breach report says the attackers "dumped NTDS," that is
  this file. The entire security posture around domain controllers exists to
  protect one file on one server.

---

## Phase 3 — a person with two names

**Macro point:** the cloud will not accept a sign-in name on a domain you cannot
prove you own. That is not bureaucracy, it is a trust boundary.

Worth saying:

- Verifying a domain means publishing a DNS record on it, which only the real
  owner can do. It is proof of ownership, and it is the reason nobody can claim
  your company's identity namespace by typing it into a form.
- Our on-premises domain ends in `.local`, which can never be verified by anyone,
  because it is not a real top-level domain. That is deliberate here, and it is
  the situation a large number of real companies are actually in.
- The failure mode is the interesting part: **it does not error.** Users sync
  successfully and arrive in the cloud with a sign-in name that was silently
  rewritten. Nobody gets an alert. The help desk finds out when people cannot log
  in.
- The fix, an alternative UPN suffix, is a five-minute change that has to be made
  before the first sync rather than after.

**Transferable idea:** the dangerous failures in identity are rarely the ones that
throw errors. They are the ones that report success while doing the wrong thing.
That was the whole finding of Lab 3, and it shows up again here.

---

## Phase 4 — connecting the two directories

**Macro point:** two decisions in this wizard matter more than everything else
combined: where passwords get checked, and what is allowed to leave the building.

**On sign-in method.** This is really the question "when the link to the office
goes down, can anyone log in?"

- Password hash synchronization sends a hash of a hash of the password to the
  cloud, so Entra ID can verify people by itself. The office can burn down and
  people still get their email.
- Pass-through authentication keeps every password check on-premises. Nothing
  password-related is stored in the cloud, which some organizations require. The
  cost is that the on-premises environment is now in the critical path for every
  single sign-in, forever.
- Federation hands authentication to a separate system you own and operate. Most
  control, most infrastructure, most ways to fail.

Say plainly that most organizations should pick the first one, and that the
reason people historically picked the others was a belief that a password hash in
the cloud is a bigger risk than making their own datacenter a single point of
failure for every login. That trade has aged badly.

**On organizational unit filtering.** This is least privilege applied to
synchronization itself.

- The default is to sync everything, and everything is almost never correct.
- Service accounts, disabled accounts, test objects, and old shared mailboxes do
  not belong in a cloud directory. Every object you sync is an object that can be
  targeted, licensed, or misconfigured.
- We deliberately excluded a container so the filtering is real and not a
  checkbox. Then in Phase 6 we go looking for what silently did not sync, because
  a filter that quietly drops something you needed looks identical to a filter
  working correctly.

**On why we chose Connect Sync over Cloud Sync.** Cloud Sync is genuinely the
better tool for a new deployment. Connect Sync is what the postings name and what
most enterprises are running. Being able to say both of those in one breath is
the answer that lands.

---

## Phases 5 through 7

**On Phase 6, and the line to land.** The strongest moment in this lab is not the
sync working. It is what the sync did to a group nobody was looking at.

A dynamic group built back in Lab 1 carries the rule `user.department -eq "Sales"`.
Two of the twelve on-premises users seeded in Phase 3 have a department of Sales.
When they synced, that group absorbed them. No click, no notification, no admin
action anywhere.

Say it in that order on camera: show the group, show the Active Directory
Organization tab with `Sales` sitting in a text box, then draw the line between
them. The point is not that dynamic groups work. It is that **synchronizing a
second directory into a tenant silently re-evaluates every rule that already
exists there against a population nobody tested them against.**

Then the closing line:

Once you soft match a cloud user, their cloud group membership is being decided by
a text box on a Windows server, filled in by whoever provisions accounts
on-premises, who may never log into Entra and may not know that group exists.

Do not rush that. Pause after it.

**On Phase 6A, the audit log, and the reveal.** Shoot this as a sequence, because
that is the order it actually happened in and the order is the whole effect.

First, show the membership count. One before the change, one after. Then say the
honest thing out loud:

I built this whole test around watching that number drop to zero. It never moved. If I had
stopped there I would have written down that nothing happened.

Then open the audit log and show the two events sitting in the same second, a
removal and an addition. Then the beat that matters:

Two events in the same second doesn't prove they're related. That could be coincidence. What
proves it is the correlation ID, and it's identical on both of them. Same operation. She wasn't
removed and then separately added. She was substituted.

Show the modified properties on each side, Sales going to blank on one, blank going
to Finance on the other.

Then the second half, and do not skip it, because it is the stronger half:

Twenty three seconds later there's an event called Change user license. I assumed the group swap
had cascaded into her licensing. I opened the diff expecting to see a license move, and the same
two SKUs were sitting on both sides of it. Nothing changed. A timestamp refreshed, that's all.
And the correlation ID doesn't match the group swap either, so the two aren't even connected.

Closing line for the phase:

So inside the same minute, one thing I was watching stayed completely silent while every
entitlement this person had got replaced, and another thing shouted at me about a change that
never happened. Neither instrument told me the truth about her access.

**Caution when you narrate this.** Do not describe a cascade from the attribute
change through the group swap into the licensing event. That was my read at the
time and it is wrong. The correlation identifiers do not match and the licensing
event has no group target. The three events are close in time and unrelated in
cause, and saying otherwise on camera is the exact reasoning error the phase
exists to demonstrate.

*(Phases 5 and 7 filled in as those are built.)*

---

## How to make it sound natural

- Explain the problem to a person, not to a camera. Imagine a colleague asking
  "wait, why does that matter?"
- Contractions. Uneven sentences. Say "the thing is" and "here's what bit me."
- Use the moments where something went wrong. Those are the parts that sound like
  a person who did the work, because nobody invents a pending-reboot error.
- Never claim more than you did. "I have not run this at enterprise scale" costs
  nothing and buys credibility for everything else you say.
- Do not read a list of features. Pick the one decision on each screen that would
  cause a real problem if it were wrong, and talk about that.
