# IAM Portfolio: Mukhtar Houry

Hands-on **Identity & Access Management (IAM)** projects, organized by the capability each one demonstrates.

I have 10+ years of real-world IAM experience (identity lifecycle management, RBAC
design, and access governance across enterprise retail, consulting, and financial
services).

**Certifications:** CompTIA Security+ · ISC2 Certified in Cybersecurity (CC)
**Currently building toward:** Microsoft SC-300 (Identity & Access Administrator)

---

## Start here

**[Leaver](leaver/)** is the one to read first. A termination reported 6 of 6 tasks complete and zero failures while the user kept a group. 8 and a half hours later a scheduled onboarding workflow gave the access back, and also reported zero failures.

Two minutes, and it covers the problem every organization has: what is supposed to happen when somebody leaves, and how you would know if it didn't.

## Tools

| Tool | Role |
|---|---|
| Microsoft Entra ID (P2 + ID Governance) | Cloud directory, dynamic groups, Conditional Access, PIM, access packages, access reviews, Lifecycle Workflows |
| Active Directory Domain Services | On-premises directory and source of authority |
| Microsoft Entra Connect Sync | Hybrid identity synchronization |
| Microsoft Graph PowerShell SDK | Detection scripts, access review data, consent auditing |

---

## Capabilities Built

### Foundations

- [Architecture and Environment](architecture-and-environment/)

### Identity Lifecycle (Joiner, Mover, Leaver)

- [Joiner: Attribute-Driven Provisioning and Onboarding Workflows](joiner/)
- [Mover: Role Changes and Silent Entitlement Swaps](mover/)
- [Leaver: Off-boarding That Says It Worked, and How to Catch It When It Didn't](leaver/)

### Identity Governance and Administration (IGA)

- [Access Requests: Approved, Expiring Access Packages](access-requests/)
- [Access Reviews: Certifying Access, and Not Trusting the Recommendation](access-reviews/)
- [Privileged Access: Just-in-Time Admin with PIM](privileged-access/)

### Access Management

- [Conditional Access: Requiring MFA Without Locking Out the Tenant](conditional-access/)
- [App Consent and Least Privilege](app-consent-least-privilege/)

### Hybrid Identity

- [Directory Sync: What the Cloud Can't See](directory-sync/)

---

## How to read these

Each project follows the same structure:

- **The risk:** the access-control problem being solved
- **What I built:** the design and the decisions behind it
- **What I found:** what actually happened, including what broke
- **What I'd recommend:** the control I'd put in place
- **What I'd do differently in a real environment**
- **Screenshots and evidence:** sanitized, from the environments I built
