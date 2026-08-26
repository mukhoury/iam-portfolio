# IAM Portfolio: Mukhtar Houry

Hands-on **Identity & Access Management (IAM)** lab work, documented as case studies.

I have 10+ years of real-world IAM experience (identity lifecycle management, RBAC
design, and access governance across enterprise retail, consulting, and financial
services). This repo is where I demonstrate that experience in modern, hands-on tooling,
one reproducible lab at a time.

**Certifications:** CompTIA Security+ · ISC2 Certified in Cybersecurity (CC)
**Currently building toward:** Microsoft SC-300 (Identity & Access Administrator)

---

## Start here

**[Identity Governance and Lifecycle Automation](labs/2-entra-identity-governance/)** is the one to read first. A termination reported six of six tasks complete and zero failures while the user kept a group. Eight and a half hours later a scheduled onboarding workflow gave the access back, and also reported zero failures.

Two minutes, and it covers the problem every organization has: what is supposed to happen when somebody joins, changes roles, or leaves.

## Labs

| # | Lab | Focus | Tools |
|---|-----|-------|-------|
| 1 | [Entra ID Dynamic Groups and Conditional Access](labs/1-entra-dynamic-groups-conditional-access/) | ABAC · dynamic groups · Zero Trust · Conditional Access | Microsoft Entra ID (Premium P2) |
| 2 | [Identity Governance and Lifecycle Automation](labs/2-entra-identity-governance/) | Access packages · access reviews · PIM · Lifecycle Workflows | Microsoft Entra ID (P2 + ID Governance) |
| 3 | [Off-boarding Detection and Consent Auditing with PowerShell](labs/3-entra-graph-powershell/) | Graph API · off-boarding detection controls · OAuth consent · just-in-time app privilege | Microsoft Graph PowerShell SDK |
| 4 | [Hybrid Identity and Directory Synchronization](labs/4-entra-hybrid-identity/) | Source of authority · sync scope as a security control · attribute-driven access · detection gaps | Active Directory Domain Services + Microsoft Entra Connect Sync |

**Short links:** [mukhoury.github.io/iam-portfolio/lab1](https://mukhoury.github.io/iam-portfolio/lab1/) ·
[lab2](https://mukhoury.github.io/iam-portfolio/lab2/) ·
[lab3](https://mukhoury.github.io/iam-portfolio/lab3/) ·
[lab4](https://mukhoury.github.io/iam-portfolio/lab4/)

---

## How to read these

Each lab is a self-contained case study with the same structure:

- **Problem:** the access-control challenge being solved
- **Solution:** the design decision and why
- **Steps:** what I actually did, reproducibly
- **Security outcome:** the control that was achieved and how it maps to real IAM job functions
- **Artifacts:** screenshots and evidence (sanitized)

**Ground rule for everything here:** if I can't explain it, it isn't in this repo.
