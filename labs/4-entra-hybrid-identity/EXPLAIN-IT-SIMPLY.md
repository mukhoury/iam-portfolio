# Explain It Simply — Hybrid Identity Without the Lingo

Plain-language versions of everything in this lab. Written for three audiences
who need the same thing:

- Course customers switching careers into IAM with no background in it
- Colleagues in HR, Finance, Legal or Audit who need to understand an access
  decision without learning the vocabulary
- Interviewers, when they ask you to explain something to a non-technical
  stakeholder, which they will

**The rule:** give the picture first, then the word for it. Never the reverse.
Someone who hears "user principal name" before they hear what problem it solves
has learned a term, not an idea.

---

## The core problem this lab solves

Picture a company that merged two offices and never combined their badge systems.

You're one person. But the old building has a record for you, and the new
building has a different record for you. Two badges. Two sets of doors. When you
change departments, somebody has to update both. When you quit, somebody has to
remember to cancel both.

They will forget. They always forget one.

**That's the entire problem.** A company has an old employee directory that has
been running for twenty years, and a new one that arrived with their cloud email.
Neither is going away. A person is one person, but the systems think they're two.

Everything else in this lab is about connecting those two systems so there's one
record for one human, **without accidentally creating a new way in.**

That last part matters more than it sounds. Every time you connect two trusted
systems, you create a hallway between them that didn't exist before. Somebody
will eventually walk down it.

> **Then give them the words:** the old system is *Active Directory*, on-premises.
> The new one is *Microsoft Entra ID*, in the cloud. Running both is called
> *hybrid identity*. The tool that connects them is *Entra Connect*.

---

## What a domain controller is

It's the bouncer with the guest list.

When you sign in to your work laptop in the morning, your laptop doesn't decide
whether you're really you. It asks the bouncer. The bouncer checks the list and
says yes or no, and everything else in the building trusts that answer without
checking again. The printer doesn't re-verify you. The file share doesn't
re-verify you.

That's why this one server matters so much. **Everyone downstream trusts its
answer completely.** If someone can make the bouncer say yes for a person who
shouldn't be on the list, every door in the building opens.

> **The words:** the bouncer is a *domain controller*. The guest list is *Active
> Directory*. The trust everything else places in it is why domain controllers get
> more protection than any other server a company owns.

---

## Why the sign-in name has to be a name the cloud recognizes

Say you want your company listed in the lobby directory of a building. The
building manager won't just take your word that you own Suite 400. They'll ask
you to prove it, by doing something only the real owner could do.

The cloud does the same thing with your company's internet name. Before it will
accept sign-in names ending in `@yourcompany.com`, you have to prove you own
`yourcompany.com`. You prove it by making a small change to that domain's public
record, something only the actual owner can do.

Now here's the trap. A lot of companies named their internal network something
like `company.local` back in 2005. **Nobody can own `.local`.** It isn't a real
internet name. So the cloud can never verify it, and it refuses to accept sign-in
names ending in it.

What happens next is the dangerous part: **it doesn't fail.** The accounts copy
over just fine, but the cloud quietly rewrites everyone's sign-in name to
something else. No error, no alert. You find out when a hundred people call the
help desk saying their login doesn't work.

> **The words:** the sign-in name is the *user principal name*, or UPN. Proving
> you own a domain is *domain verification*. The fix is adding an *alternative
> UPN suffix*, and you have to do it before the first sync, not after.

---

## Where the password gets checked, and why it's the biggest decision

When you connect the two systems, you have to answer one question: **when
somebody types their password, who checks it?**

Three answers, and it's easier to see them as a building with a front desk.

**Option one.** The new building keeps a scrambled copy of everyone's key, so it
can check people in on its own. If the road to the old building floods, everyone
still gets to work.

**Option two.** Every time someone shows up at the new building, the front desk
phones the old building to confirm. Nothing about the keys is ever stored in the
new place, which some companies require for legal reasons. The cost: if that
phone line ever goes down, **nobody gets in anywhere.** You've made the old
building a single point of failure for every door in the company, permanently.

**Option three.** You hire a separate security firm to do all the ID checking.
Most control over exactly how it works, and by far the most equipment to
maintain and the most things that can break.

Most companies should pick option one. The reason many historically picked option
two was a belief that storing anything password-related in the cloud was riskier
than making their own building a permanent single point of failure. That belief
has aged badly.

> **The words:** option one is *password hash synchronization*. Option two is
> *pass-through authentication*. Option three is *federation*. And option one
> doesn't store your password, it stores a scrambled version of an already
> scrambled version, which can't be turned back into your password.

---

## Why you don't copy everything over

When you connect the two directories, the default is to copy **everything.**
That's almost never right.

Your employee list contains more than employees. There's the account the backup
software uses at 2 a.m. There's the account for the badge reader in the parking
garage. There are people who left in 2019 whose accounts were disabled but never
deleted. There's a test account somebody made in 2014 called `testuser2`.

None of that belongs in your cloud directory. **Every account you copy over is
one more account someone can attack, one more you might accidentally pay a
license for, and one more that can be misconfigured.**

So you choose which parts of the company get copied and which stay behind. It's
the same instinct as giving the janitor a key to the supply closet and not to the
CFO's office. Nobody needs access to everything.

> **The words:** choosing what syncs is *organizational unit filtering*. The
> principle underneath it is *least privilege*, which is the single most useful
> phrase in this entire field: give exactly the access needed, for exactly as
> long as it's needed, and no more.

---

## The finding worth telling everyone

Here's something that happened in this lab, and it's the best example of "closing
one gap opens another" that I've got.

A company can be extremely careful about who gets keys to the building. They
review the key list every quarter. They know exactly who holds a master key.

But the building sits on land they rent, and the landlord's maintenance crew has
their own way in. Not a key, a completely separate door that has nothing to do
with the key system. Nobody reviewing the key list ever sees it, because it isn't
on the key list.

That's what happened here. The bouncer's server runs inside a cloud account. And
anybody with ordinary administrative rights over that **cloud account** can push
instructions straight into the server, without a password, without a login, and
without ever appearing in the list of people with directory access.

I did it during this lab. I created twelve employee accounts in the company
directory from a laptop with no company credentials at all.

**So if you audit who has master keys but you never ask who can get into the
building another way, you've audited half the problem.** Two different teams
usually own those two lists, and neither one is wrong on its own. It's the
combination that's the hole.

> **The words:** the master key list is *Domain Admins*. The landlord's separate
> door is a *Contributor* role assignment in Azure. The lesson is that
> *control-plane access equals guest access*, and it's a genuinely good thing to
> raise in an interview.

---

## How to use this when you're explaining out loud

**Lead with the consequence, not the mechanism.** Nobody outside IT cares how
synchronization works. They care that a person who quit still has access.

**One analogy per idea, and don't mix them.** If you started with a building,
stay in the building. Switching from buildings to bank vaults to airports halfway
through loses people.

**Say the scary version plainly.** "Someone who left the company two years ago
could still read our files" moves a budget. "Deprovisioning gaps in the identity
lifecycle" does not.

**Give the word last, and only once.** People remember the picture and forget the
term, which is fine. They'll recognize the term next time they hear it, and that
is all you need.

**Admit what you don't know.** In this field, credibility is the product. Someone
who says "I haven't run this at that scale" is more believable on everything else
they say.
