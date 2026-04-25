# bluemotion-salesforce — Blue Motion Consulting Experience Cloud Site

## Overview
Salesforce DX project for Blue Motion Consulting LLC (bluemotionconsulting.com). This is Tony DeGregorio's consulting portfolio, built as an Experience Cloud LWR site that doubles as a live demo of Salesforce architecture skills. The site itself IS the proof of competency.

**Org:** Blue Motion Consulting LLC Developer Edition
**Username:** tonydegregorio@agentbuilder123.com
**Alias:** bluemotion
**Site URL:** bluemotionconsultingllc-dev-ed.develop.my.site.com

## Project Structure
```
bluemotion-salesforce/
├── CLAUDE.md
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/           # Apex controllers, services, domain, selectors
│           ├── lwc/               # Lightning Web Components
│           ├── flows/             # Screen flows, record-triggered flows
│           ├── objects/           # Custom objects and fields
│           ├── permissionsets/    # Guest user and site permissions
│           ├── triggers/         # Apex triggers
│           ├── customMetadata/   # CMT records (kill switches, config)
│           ├── platformEventChannelMembers/
│           └── experiences/      # Experience Cloud site metadata
├── scripts/                      # Utility scripts, data loading
├── config/                       # Scratch org and environment configs
└── sfdx-project.json
```

## Architecture Principles

### Trigger Framework
Use the GLBL_SObjectDomain pattern (modified fflib/Kevin O'Hara trigger handler):
- One trigger per object, delegates to domain class
- CMT kill switches for runtime bypass
- Domain classes extend GLBL_SObjectDomain
- Naming: `[ObjectName]TriggerHandler` for triggers, `[ObjectName]Domain` for domain classes

### Apex Patterns
- **Separation of concerns:** Selector → Domain → Service layers (fflib-inspired)
- **Naming conventions:**
  - Selectors: `[ObjectName]Selector.cls`
  - Domain: `[ObjectName]Domain.cls`
  - Service: `[FeatureName]Service.cls`
  - Controllers (LWC): `[ComponentName]Controller.cls`
  - Test classes: `[ClassName]Test.cls`
- **Sharing:** Explicit `with sharing` on all classes unless documented reason for `without sharing`
- **No hardcoded IDs.** Use Custom Metadata, Custom Labels, or Custom Settings
- **Bulkification:** All Apex must handle collections, never single records
- **Test coverage:** Minimum 85%. No fake coverage methods. Test behavior, not lines.

### LWC Conventions
- All components built for **LWR Experience Cloud** (not Aura)
- Component naming: camelCase folders, matching JS/HTML/CSS files
- Prefix custom components with `bmc` (Blue Motion Consulting): `bmcHeroSection`, `bmcLeadForm`
- Use `@wire` for read operations, imperative Apex for DML
- Lightning Design System (SLDS) for base styling, custom CSS for brand differentiation
- All components must be mobile-responsive
- Expose properties via `@api` with JSDoc comments

### Experience Cloud (LWR)
- LWR only — no Aura pages or components
- Guest user profile must be locked down — minimal object/field access
- All guest-accessible Apex must use `with sharing` and explicit CRUD/FLS checks
- Content that changes frequently should be driven by `Site_Content__c` records, not hardcoded

### Flows
- Screen flows for interactive user experiences (lead capture, configurator)
- Naming: `BMC_[Feature]_[Type]` (e.g., `BMC_LeadCapture_ScreenFlow`)
- Use custom labels for user-facing text where reuse is expected
- Fault paths on every element that can fail

### Security — CRITICAL
This is a public-facing Experience Cloud site. Security is non-negotiable:
- Guest user has NO access beyond what is explicitly granted
- All Apex controllers verify CRUD/FLS before DML
- No SOQL injection — use bind variables
- No sensitive data exposed to guest context
- Platform Event subscribers validate payload before processing
- API callouts use Named Credentials, never hardcoded endpoints

## Data Model

### Custom Objects
- `Service__c` — Consulting service offerings (drives Services page dynamically)
- `Case_Study__c` — Portfolio pieces (problem, approach, outcome, tags)
- `Stack_Result__c` — Configurator recommendation results
- `Site_Content__c` — Lightweight CMS for dynamic page content

### Standard Objects Used
- `Lead` — Contact form submissions

## Site Pages & Portfolio Pieces

### Site Pages
1. **Home** — Custom LWC hero component, value prop, CTA
2. **Services** — Data-driven from `Service__c` records via custom LWC
3. **Portfolio / Case Studies** — From `Case_Study__c`, interactive architecture decision tool
4. **Contact** — The Over-Engineered Lead Form (see below)
5. **Agentforce Demo** — Embedded Agentforce agents

### Portfolio Piece 1: "Build Your Salesforce Stack" Configurator
- **What:** Agentforce-driven conversational tool on Experience Cloud
- **How it works:** Visitor chats with an Agentforce agent, describes their industry/size/pain points, gets a tailored Salesforce architecture recommendation
- **Data:** Creates Lead + Stack_Result__c record
- **Personality:** Helpful but has humor. After delivering results: "This is the part where a normal website would put your email behind a gate. But we're not normal. Here's your recommendation. If you want the human who built me to dig deeper — he's pretty good too."
- **Demonstrates:** Agentforce on Experience Cloud, topic/action design, conversational UX

### Portfolio Piece 2: "Will Salesforce Fix That?" Magic 8-Ball
- **What:** Agentforce agent that answers Salesforce frustrations
- **How it works:** Visitor types a Salesforce complaint/question, agent responds with a mix of real answers (with release notes) and sarcastic Magic 8-Ball responses
- **Sample responses:**
  - "Outlook not so good. But neither is your org."
  - "Signs point to yes... in 2031."
  - "My sources say no. My sources are the Known Issues list."
  - "Actually, that shipped in Spring '25. Here's the release note." (real answer)
- **Demonstrates:** Agentforce personality design, grounding in real Salesforce knowledge

### Portfolio Piece 3: Trigger Framework Playground
- **What:** Interactive LWC visualization of the GLBL_SObjectDomain trigger framework
- **How it works:** Visitor picks a scenario (Before Insert, After Update, etc.), sees the execution path visualized — handler routing, domain class invocation, CMT kill switch evaluation
- **Key feature:** Toggle a kill switch on/off and watch the execution path change in real time
- **Implementation:** Pure client-side LWC, framework structure defined in JSON, no guest user Apex needed
- **Demonstrates:** Enterprise trigger framework design, CMT governance patterns

### Portfolio Piece 4: The Over-Engineered Lead Form
- **What:** A contact form that's intentionally, comically over-architected — and self-aware about it
- **Toggle:** "Normal Mode" (3-field form, instant submit) vs "Enterprise Architecture Mode" (the full experience)
- **Steps in Enterprise Mode:**
  1. **"The Basics"** — Name + Email with custom LWC inputs, real-time duplicate detection on blur. Commentary: "Step 1 of 11. Yes, eleven. We take contact forms seriously."
  2. **"Address Verification"** — API callout geocodes address, renders map, shows button: "Click Here to Dispatch the Agentforce Drone Army." Click triggers modal with fake deployment screen: "Deploying AgentforceDroneArmy_v47.cls to Production..." → "DEPLOYMENT FAILED. Code coverage: 74%. You need 75%." → "1 test failed: testDroneSwarmInitialization — System.AssertException: Expected: world domination, Actual: null"
  3. **"Company Intelligence"** — Company name triggers enrichment logic. Commentary: "Normally this is where we'd charge $50k for a Data Cloud integration. Today it's free."
  4. **"Risk Assessment"** — Fake approval matrix. Commentary: "Running your submission through our 47-step approval process... Approved. It was always going to be approved."
  5. **"The Enterprise Event Bus"** — Platform Event fires, trigger consumes it, invokes Queueable. Commentary: "Your name and email are now traveling through a Platform Event → Trigger → Queueable chain. Total fields saved: 2."
  6. **"Confirmation & The Reveal"** — Mock debug log of everything that fired. CTA: "If this made you laugh and slightly concerned about my priorities, imagine what I could build for your org."

- **UI Gags:**
  - Runaway NEXT button — dodges on click, "Ha, too slow. Try again." Lets through after 2-3 attempts.
  - Progress bar goes backwards — hits 90%, drops to 40%. "Sorry, we found more architecture to add."
  - Honest loading spinner — cycles: "Instantiating service layer..." → "Invoking trigger handler..." → "Checking governor limits..." → "Wondering if this could've been a validation rule..." → "It could have." → "Proceeding anyway."
  - Terms & Conditions — fake 47-page modal. "Section 1: You agree this form is over-engineered. Section 2: See Section 1."
  - Running counter — "Platform features invoked: 14. Fields captured: 2."
  - Submit button evolution — starts: "Submit (pending architectural review)" → ends: giant green "DEPLOY TO PRODUCTION"
  - Confetti explosion on submit

- **Platform features demonstrated:** Custom LWC, Screen Flow, Validation Rules, Duplicate Rules, Before-Insert Trigger (GLBL_SObjectDomain), Platform Events, Queueable Apex, API Callouts, Approval Process (mock), Custom Metadata Types, Experience Cloud Guest User context
- **Actually works:** Despite the theater, creates a real Lead record

## Git Workflow
- `main` = production-deployed metadata
- `dev` = working branch
- Feature branches off `dev`: `feature/over-engineered-form`, `feature/stack-configurator`
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`
- Deploy command: `sf project deploy start --target-org bluemotion`

## Deployment
- Direct SFDX deployment via SF CLI (no Copado — overkill for solo dev)
- `sf project deploy start` for push to org
- `sf project retrieve start` to pull changes made in Setup/Builder
- Always retrieve after making changes in Experience Builder UI

## Brand & Tone
- Professional but personality-forward — not corporate
- Humor is a feature, not an accident
- Self-aware about Salesforce platform quirks
- The site should make a hiring manager laugh AND want to hire Tony
- The code should make a tech lead nod in approval

## Important Reminders
- This is a **Developer Edition** org — governor limits are real but data limits are tight (5MB)
- Custom domains are NOT supported on Dev Edition — don't attempt to configure one
- All components must work in the **guest user context** — no authenticated-only patterns
- Test with the actual Experience Cloud site, not just in the org's Lightning app
- Experience Builder changes must be retrieved back to source — they don't auto-sync
