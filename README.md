# IAM Portfolio: Mukhtar Houry

Hands-on **Identity & Access Management (IAM)** lab work, documented as case studies.

I have 10+ years of real-world IAM experience (identity lifecycle management, RBAC
design, and access governance across enterprise retail, consulting, and financial
services). This repo is where I demonstrate that experience in modern, hands-on tooling,
one reproducible lab at a time.

**Certifications:** CompTIA Security+ · ISC2 Certified in Cybersecurity (CC)
**Currently building toward:** Microsoft SC-300 (Identity & Access Administrator)

---

## Labs

| # | Lab | Focus | Tools |
|---|-----|-------|-------|
| 1 | [Entra ID Dynamic Groups & Conditional Access](labs/1-entra-dynamic-groups-conditional-access/) | ABAC · dynamic groups · Zero Trust · Conditional Access | Microsoft Entra ID (Premium P2) |
| 2 | [Entra ID Identity Governance](labs/2-entra-identity-governance/) | Access packages · access reviews · PIM · Lifecycle Workflows | Microsoft Entra ID (P2 + ID Governance) |
| 3 | [Offboarding Detection & Consent Auditing with Microsoft Graph PowerShell](labs/3-entra-graph-powershell/) | Graph API · offboarding detection controls · OAuth consent · just-in-time app privilege | Microsoft Graph PowerShell SDK |

**Short links:** [mukhoury.github.io/iam-portfolio/lab1](https://mukhoury.github.io/iam-portfolio/lab1/) ·
[lab2](https://mukhoury.github.io/iam-portfolio/lab2/) ·
[lab3](https://mukhoury.github.io/iam-portfolio/lab3/)

*Application Identity (app registrations, SSO/SAML/OIDC) is next.*

---

## How to read these

Each lab is a self-contained case study with the same structure:

- **Problem:** the access-control challenge being solved
- **Solution:** the design decision and why
- **Steps:** what I actually did, reproducibly
- **Security outcome:** the control that was achieved and how it maps to real IAM job functions
- **Artifacts:** screenshots and evidence (sanitized)

**Ground rule for everything here:** if I can't explain it, it isn't in this repo.
