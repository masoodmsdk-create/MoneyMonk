MoneyMonk — Universal Coding Agent Context & Skill

1. Project Identity

Product name: MoneyMonk

Parent/brand identity: MSD

MoneyMonk is a completely new, standalone financial advisor application. It is not FINAURA and must never inherit FINAURA's navigation, architecture, terminology, visual patterns, feature set, or complexity.

The visible product name in the application is simply:

MoneyMonk

MSD may be used subtly for legal/about/footer/internal purposes, but do not prominently label the product as "MoneyMonk by MSD" and do not invent another brand name.

GitHub repository: https://github.com/masoodmsdk-create/MoneyMonk

Firebase project: moneymonk-d5605

Hosting: Firebase

The repository may initially be empty. Do not assume that an existing application, framework, architecture, or component library exists. Inspect the repository first and build MoneyMonk cleanly from the ground up.

Implementation guardrails for this project:

- The fixed technology stack is Flutter + Dart + Firebase.
- Do not switch to React, Vite, TypeScript, Next.js, Vue, Angular, or another frontend framework.
- Use Flutter's built-in state management where practical and keep dependencies minimal.
- This project should be created from a clean Flutter app when the repository is empty.
- The original Stage 1 scope was the app foundation, visual shell, Money screen, Loans screen, empty states, and navigation. The current project has progressed beyond Stage 1; preserve the implemented MVP behavior unless the product owner explicitly changes scope.

2. Non-Negotiable Product Philosophy

MoneyMonk exists to solve one problem:

Help an ordinary person understand and record their money with almost no learning curve.

The experience must follow:

Open → see your money → Add → save.

A first-time user must be able to use the application without:

a tutorial

onboarding documentation

an explanation page

an AI assistant

a complicated dashboard

financial jargon without explanation

configuration screens

unnecessary setup

If a feature requires explaining before the user can understand it, simplify the feature.

The most important rule

Build less, not more.

Do not add features merely because they are common in finance apps.

Do not turn MoneyMonk into a general-purpose personal-finance platform.

When there is a choice between:

a clever solution and a simple solution,

a configurable solution and a sensible default,

a multi-step flow and a single flow,

choose the simpler solution.

3. Product Scope

MoneyMonk has exactly two primary sections:

Money

Loans

That is the core product.

Do NOT add:

Analytics

Insights

Goals

Budgets

Investments

Tax planning

Bank integrations

Account aggregation

AI chatbot

Notifications

Complex reports

Categories unless they become absolutely necessary

Tags

Payment methods

Multiple account types

Gamification

Social features

Marketplace

Subscription management

Unrequested settings

Unrequested profile systems

Unrequested admin dashboards

If a requirement is not explicitly described in this document, prefer not to build it.

4. UX Standard

MoneyMonk should feel:

modern

clean

premium

calm

trustworthy

spacious

simple

financially serious

easy for a first-time user

It must NOT look like:

an admin dashboard

a spreadsheet

a generic CRUD application

a developer prototype

an old banking website

a dense accounting application

Modern design should come from:

typography

spacing

hierarchy

alignment

consistency

restraint

Do not create visual complexity just to make the app look "modern."

Avoid:

heavy gradients

glassmorphism

neon effects

excessive shadows

excessive cards

excessive pills

excessive icons

unnecessary animations

decorative illustrations that do not help the user

5. Visual Design System

Brand palette

Use this visual system consistently.

Deep Navy primary: #1E3A5F
Navy light:        #EAF1F8
App background:    #F7F9FB
Surface:           #FFFFFF
Primary text:      #172033
Secondary text:    #647084
Muted text:        #8B95A5
Border:            #E1E6ED
Income:            #15803D
Expense:           #C2410C
Warning:           #B45309
Error:             #B91C1C

Use deep navy primarily for:

primary buttons

active navigation

selected controls

important interactive elements

brand/logo treatment

important highlights

Do not make the entire application navy.

Typography

Use Inter throughout.

Recommended hierarchy:

Page title:       28px / 700
Section heading:   20px / 600–650
Main balance:      32px / 700
Financial numbers: 22–24px / 700
Body:              15px / 400
Table:             14px
Labels:            13px / 500
Secondary text:    13px / 400
Buttons:           14px / 600

Use tabular/lining numerals for financial amounts where supported.

Shape and surfaces

Border radius: approximately 10–14px

Minimal shadow

Prefer subtle borders

Use whitespace generously

Maintain strong visual hierarchy

6. Money Section

The Money screen is the working dashboard.

There must NOT be a separate "dashboard" followed by a separate "transactions" page.

The main Money screen itself is where the user sees and manages their money.

Empty state

A new user must see an empty table.

Do NOT insert:

demo transactions

fake salaries

sample expenses

fake charts

fake balances

placeholder financial data

The empty state should still look polished.

The balance should initially be:

₹0

7. Money Table — Critical Requirement

Income and Expense MUST appear side by side in the SAME table.

Do NOT create:

a Type column

separate Income and Expense tables

a vertical transaction feed as the primary interface

The conceptual structure is:

| Income       | Amount    | Expense       | Amount    |
| Salary       | ₹80,000   | Rent          | ₹20,000   |
| Freelance    | ₹15,000   | Electricity   | ₹3,000    |
|              |           | Groceries     | ₹8,000    |
| Total Income | ₹95,000   | Total Expense | ₹33,000   |

Rules:

Income is always on the left.

Expense is always on the right.

Each side is independent.

The number of income rows does NOT need to equal the number of expense rows.

Do not create blank fake entries merely to make rows match.

Totals belong at the bottom of their respective sides.

Balance placement

Immediately below the table, show:

Balance

Formula:

Balance = Total Income - Total Expense

For an empty account:

Balance = ₹0

Do not move Balance to another part of the dashboard.

8. Money Controls

The Money screen should have one obvious primary action:

+ Add

The user should not have to decide whether to navigate to a separate income page or expense page.

Clicking + Add should provide a simple way to choose:

Income

Expense

Then collect only what is needed.

9. Add Money Flow

The Add flow must be simple.

Required fields

Type

Income

Expense

Name

Examples:

Salary

Rent

Electricity

Groceries

Freelance

Do not force a category.

Amount

Currency should be presented naturally for the user's locale, with Indian Rupee support:

₹

When

Choose:

One time

Recurring

One-time

If One time is selected, allow the user to choose the relevant date/month.

The item should appear only in that selected period.

Recurring

If Recurring is selected, allow:

Monthly

Every 2 months

Quarterly

Half-yearly

Yearly

Also collect:

Start date

The user should not need to manually create every future occurrence.

10. Recurring Money Behaviour

Recurring entries must automatically populate future applicable periods.

Example:

Rent
₹20,000
Monthly
Start: September 2026

The user should see the appropriate occurrence in future months automatically.

Important exception/edit behaviour

Suppose a recurring expense is normally:

Groceries — ₹3,000

but one month it becomes:

Groceries — ₹3,700

The user must be able to edit that month's occurrence to ₹3,700 without changing the recurring default for future months.

Future months should continue using:

₹3,000

The implementation may use any internal model necessary, but the UI must remain simple.

The user should never need to understand terms such as:

recurrence rule

generated transaction

occurrence instance

override record

Those are implementation concepts, not user concepts.

11. Month and Year Views

Provide a simple month selector such as:

‹ September 2026 ›

The Money screen should support:

Monthly | Yearly

Monthly

Show the money applicable to the selected month.

Yearly

Aggregate the same underlying data for the selected year.

Do not create a complicated reporting system.

12. Automatic Forecast

MoneyMonk should automatically forecast future money based on:

recurring entries

one-time entries where applicable

The forecast should require no separate planning workflow.

A simple structure is enough:

| Month | Income | Expense | Balance |

The forecast should be factual and derived from entered data.

Do not introduce a complex forecasting engine, financial prediction model, or AI.

13. Money Data Principles

The implementation should keep money calculations reliable and deterministic.

Prefer storing monetary values in the smallest currency unit (for example, paise) or another precise integer representation rather than floating-point arithmetic.

The UI should format amounts as Indian Rupees where appropriate.

Never allow rounding errors to silently affect:

totals

balances

recurring calculations

forecasts

loan calculations

Centralize money calculation/formatting logic instead of duplicating it across components.

14. Loans Section

Loans must follow the same simplicity philosophy.

Empty state

Show:

No loans added yet

and:

+ Add Loan

Do not show fake loans.

15. Add Loan

Adding a loan should be a single simple form, not a multi-step wizard.

Required fields:

Loan name

Example:

Home Loan

Original loan amount

Explain clearly:

Amount originally borrowed.

Current outstanding amount

Explain clearly:

Principal still owed today.

Interest rate / ROI

Explain clearly:

Annual interest rate charged on the loan.

EMI

Explain clearly:

Amount paid each month.

Loan start date

Tenure

Allow years/months as appropriate.

Explain clearly:

How long the loan is scheduled to run.

Primary action

Save Loan

The form must explain the meaning of the terms directly where the user sees them.

The user should not need external documentation to understand:

outstanding

principal

ROI

EMI

tenure

16. Loan Details After Saving

Immediately after saving a loan, show:

Current Outstanding

Original Loan

EMI/month

Interest Rate

Remaining Principal

Estimated Remaining Interest

Expected Completion

Keep this presentation easy to scan.

Do not overwhelm the user with financial formulas.

17. Loan Forecast

Loan forecasting must use a proper reducing-balance amortization model.

Each month:

Calculate interest on the current outstanding principal.

EMI is applied.

Interest is covered first.

Remaining EMI reduces principal.

Outstanding balance decreases.

Stop when the loan is fully paid.

Handle the final payment correctly if it is smaller than the normal EMI.

The yearly forecast should be:

| Year | Principal Paid | Interest Paid | Remaining Balance |

Do not use simplistic calculations such as:

Original Loan / Tenure

for principal repayment when a reducing-balance model is required.

Invalid EMI condition

If the EMI is insufficient to repay the loan because interest consumes the payment or otherwise makes amortization invalid, do not produce a misleading forecast.

Clearly flag the problem to the user.

18. Multiple Loans

The user may add multiple loans.

The loan list should remain simple:

| Loan | Outstanding | EMI | ROI |

Do not turn it into a complex loan-management system.

19. Loan Comparison

Provide a simple comparison across loans using:

Outstanding

EMI

ROI

Remaining tenure

Estimated remaining interest

Expected completion

The goal is understanding, not financial complexity.

20. Simple Loan Advice

MoneyMonk may provide deterministic factual guidance.

Example:

Your Personal Loan has the highest interest rate.

Or:

This loan has the highest remaining interest cost.

A simple recommendation may be:

Focus on the loan with the highest interest rate first.

Include a sensible caveat where appropriate:

Check for any prepayment charges or restrictions before making an extra payment.

Do NOT implement an AI chatbot.

Do NOT pretend to provide personalized regulated financial advice.

The advice should be based on visible calculated facts.

21. Responsive Design

MoneyMonk must work properly on:

desktop

tablet

mobile

The mobile design must not simply shrink the desktop layout.

On mobile:

preserve the conceptual Income + Amount | Expense + Amount structure

reflow/stack intelligently when necessary

avoid page-level horizontal scrolling

keep actions easy to tap

keep financial numbers readable

The table may use a responsive transformation if necessary, but it must remain conceptually obvious which values are Income and which are Expense.

Do not sacrifice usability merely to preserve a literal four-column desktop layout on a small screen.

22. Accessibility

Use:

semantic HTML where applicable

visible labels

accessible form controls

clear focus states

keyboard accessibility

sufficient contrast

touch-friendly controls

meaningful error messages

accessible names for icon buttons

Do not rely on color alone to communicate meaning.

23. Technical Architecture Rules

Because the repository may be empty:

Inspect the repository.

Inspect existing configuration.

Inspect Firebase-related files if present.

Determine the smallest sensible production-ready architecture.

Build from the ground up if no application exists.

Do not import architecture from unrelated projects.

Choose a simple, maintainable frontend stack that works well with Firebase Hosting and is appropriate for this application.

Do not introduce a framework, library, state-management system, component system, or backend service merely because it is popular.

Use dependencies only when they materially improve the implementation.

Keep the architecture understandable to another developer.

Prefer:

small components

clear domain logic

centralized calculations

explicit data models

predictable state

minimal abstractions

minimal dependencies

Avoid:

over-engineering

unnecessary design-system layers

excessive generic components

unnecessary repository patterns

speculative microservices

premature optimization

24. Persistence and Firebase

Firebase is the deployment platform for MoneyMonk.

Use the existing Firebase project:

moneymonk-d5605

Before changing Firebase configuration:

inspect existing configuration

preserve working configuration where possible

do not overwrite unrelated settings blindly

If persistent user data is required, implement it in the simplest secure way that fits the project's actual architecture.

Do not add cloud functions, analytics, or other Firebase services unless they are genuinely required by the implemented product. User accounts are now part of the product scope, but the current MVP uses local username/password accounts until a secure Firebase Authentication migration is configured.

Never expose private credentials or secrets in frontend code.

Do not commit secret files or credentials.

25. Data Model Principles

The exact implementation may vary, but the conceptual data model should support:

Money entry

id
type: income | expense
name
amount
schedule:
  type: one-time | recurring
  frequency (if recurring)
  startDate
  oneTimeDate (if one-time)

The model must also support a per-occurrence override for recurring entries so that editing one month does not alter future defaults.

Loan

id
name
originalAmount
outstandingAmount
interestRate
emi
startDate
tenure

The implementation may add internal metadata when necessary.

Do not expose internal implementation concepts in the UI.

26. Calculation Rules

All important calculations must be deterministic and testable.

Money:

Total Income = sum of applicable income
Total Expense = sum of applicable expense
Balance = Total Income - Total Expense

Loan:

Monthly interest = current principal × monthly interest rate
Principal payment = EMI - monthly interest
New principal = current principal - principal payment

Handle:

zero interest

final partial payment

rounding

loan already close to payoff

invalid EMI

long tenures

multiple loans

Avoid floating-point accumulation where it can create visible financial errors.

27. Validation

Validate user input before saving.

Examples:

Name cannot be empty.

Amount must be a valid positive monetary value.

Interest rate must be valid.

EMI must be valid.

Dates must be valid.

Tenure must be valid.

Loan outstanding should not exceed the original loan without a clear reason.

Invalid loan amortization must be flagged.

Validation messages should be written for normal users, not developers.

Bad:

NaN

Good:

Please enter a valid amount.

Bad:

Invalid amortization state

Good:

This EMI is not enough to cover the current interest, so the loan cannot be repaid with these values.

28. Error Handling

Errors should be:

clear

short

actionable

non-technical

Never expose stack traces or implementation details to ordinary users.

If an operation fails, preserve user-entered data where practical.

Do not silently discard saved data.

29. Code Quality

Code should be:

readable

maintainable

type-safe where the chosen stack supports it

logically organized

tested where calculations are involved

free of dead code

free of unnecessary duplication

Do not optimize prematurely.

Do not create abstractions without a real need.

Comments should explain why, not restate obvious code.

30. Testing Requirements

At minimum, test the financial logic thoroughly.

Money tests

Test:

empty data

income only

expense only

income + expense

multiple income entries

multiple expense entries

one-time entries

monthly recurring entries

every-2-month recurring entries

quarterly recurring entries

half-yearly recurring entries

yearly recurring entries

recurring start dates

occurrence overrides

monthly totals

yearly aggregation

balance calculations

forecast calculations

Loan tests

Test:

zero-interest loan

normal reducing-balance loan

multiple loans

final partial payment

exact payoff

invalid EMI

rounding

remaining interest

expected completion

yearly principal/interest totals

Financial calculations are high-priority logic and should not be left untested.

31. UX Acceptance Tests

Before considering MoneyMonk complete, verify these manually:

First-time user

App opens successfully.

User immediately understands what MoneyMonk is for.

Money screen is visible.

No fake financial data exists.

Empty table is clean.

Balance shows ₹0.

+ Add is obvious.

Add income

User can add Salary.

It appears on the Income side.

Total Income updates.

Balance updates.

Add expense

User can add Rent.

It appears on the Expense side.

Total Expense updates.

Balance updates.

Recurring entry

User can create a recurring entry.

Future applicable months automatically contain it.

User does not have to re-enter it.

Recurring override

User can change one month's recurring amount.

Future months still use the recurring default.

One-time entry

It appears only in its selected period.

Yearly view

Yearly totals correctly aggregate the monthly data.

Loan

User can add a loan without external explanation.

Loan terms are explained directly in the form.

Calculated loan information appears after saving.

Forecast uses reducing-balance amortization.

Invalid EMI is clearly flagged.

Multiple loans can be compared.

Responsive

Desktop works.

Tablet works.

Mobile works.

No page-level horizontal scroll.

Primary actions remain easy to access.

32. Agent Working Method

When asked to implement something:

Step 1 — Understand before changing

Inspect:

repository structure

package configuration

existing source

Firebase configuration

build scripts

test setup

deployment configuration

Do not guess.

Step 2 — Confirm scope

Relate the requested work to the MoneyMonk requirements in this document.

If the requested change introduces unnecessary scope, prefer the simpler implementation.

Step 3 — Implement the smallest complete solution

Do not build speculative functionality.

Do not add future features "while you are there."

Step 4 — Validate

Run the relevant:

type checks

lint checks

unit tests

build

Firebase/deployment validation where appropriate

Fix issues before declaring the work complete.

Step 5 — Review visually

For UI work, verify:

spacing

typography

alignment

responsive behaviour

empty states

buttons

forms

financial number formatting

mobile behaviour

Step 6 — Report clearly

At the end, state:

what was changed

what was tested

any remaining issues

any assumptions made

Do not claim something was tested if it was not actually tested.

33. Incremental Development Rule

Do not attempt to create the entire application in one giant uncontrolled change when smaller increments are practical.

Prefer this general sequence:

Establish the application shell and visual foundation.

Implement Money empty state and table.

Implement Add Money.

Implement recurring/one-time behaviour.

Implement monthly/yearly views and forecast.

Implement Loans.

Implement loan calculations and forecast.

Implement multiple-loan comparison and factual advice.

Add persistence if required by the chosen architecture.

Test, polish, and deploy.

After each meaningful stage:

build

test

fix

keep the application runnable

Do not leave the repository in a broken intermediate state unless the current task explicitly requires a migration that cannot remain runnable.

34. Git and Change Discipline

Make focused changes.

Avoid:

unrelated refactoring

renaming large numbers of files without reason

formatting the entire repository unnecessarily

changing dependency versions without need

modifying Firebase configuration without understanding it

mixing unrelated features in one change

Keep commits/changes understandable when the environment supports commits.

35. Security Rules

Never:

commit secrets

hard-code private credentials

expose service-account credentials in frontend code

weaken Firebase security rules just to make development easier

store sensitive data unnecessarily

If Firebase/Firestore is used, security rules must reflect the actual data ownership model.

Do not assume all application data should be publicly readable or writable.

36. Strict Anti-Scope-Creep Rules

The following are explicit prohibitions unless the product owner later asks for them:

Do not add FINAURA features.

Do not add analytics.

Do not add an AI assistant.

Do not add investment tracking.

Do not add tax tools.

Do not add budgeting systems.

Do not add goals.

Do not add bank integrations.

Do not add notifications.

Do not add complex reports.

Do not add unnecessary categories.

Do not add unnecessary settings.

Do not add fake/demo data.

Do not add a complicated dashboard.

Do not create a separate transaction-management experience when the Money dashboard can handle the job.

Do not turn a simple requirement into a configurable enterprise system.

37. FINAURA Separation Rule

MoneyMonk is a fresh product.

Never:

import FINAURA code

copy FINAURA navigation

copy FINAURA terminology

copy FINAURA architecture

copy FINAURA components

copy FINAURA feature assumptions

recreate FINAURA under a new name

If old FINAURA-related files somehow appear in the repository, treat them as unrelated unless the product owner explicitly instructs otherwise.

The correct assumption is:

MoneyMonk starts clean.

38. Decision Rule for Ambiguous Requirements

When something is ambiguous, use this priority order:

Explicit MoneyMonk requirements

Simplicity

First-time-user usability

Financial correctness

Accessibility

Responsive behaviour

Maintainability

Visual polish

Do not choose complexity merely because it is technically impressive.

If a requirement can be satisfied in two ways, prefer the one with fewer concepts exposed to the user.

39. Definition of Done

A MoneyMonk feature is done only when:

It satisfies the stated product requirement.

It fits the MoneyMonk visual system.

It does not introduce unnecessary scope.

It works on desktop and mobile where applicable.

It has sensible validation.

Financial calculations are correct.

Relevant tests pass.

The application builds successfully.

No fake data has been introduced.

No secrets have been introduced.

The UI is understandable without documentation.

The change does not accidentally reintroduce FINAURA patterns.

40. Final Agent Instruction

You are not building a feature-rich finance platform.

You are building MoneyMonk:

A very simple, modern financial advisor that lets a person see their money, add income and expenses, understand their balance, and understand their loans.

When in doubt:

Simplify.

When tempted to add a feature:

Do not add it unless it is explicitly required.

When tempted to copy an existing architecture:

Inspect first and build cleanly for MoneyMonk.

When tempted to make the UI more sophisticated:

Prefer clarity over decoration.

The product should feel so straightforward that a first-time user can open it and immediately know what to do.

41. Spreadsheet-Style Money Input

The Add Money experience should support entering multiple money items in one batch using a simple table-like grid.

Each editable row represents one item and should provide:

- Type: Income or Expense
- Item/description
- Amount in Indian rupees
- Schedule: One time or Recurring
- Frequency for recurring rows: Monthly, Every 2 months, Quarterly, Half-yearly, or Yearly

The user must be able to mix income and expense rows in the same batch, for example:

| Type | Item/description | Amount | Schedule | Frequency |
|---|---|---:|---|---|
| Income | Salary | ₹80,000 | Recurring | Monthly |
| Expense | Rent | ₹20,000 | Recurring | Monthly |
| Expense | Insurance | ₹15,000 | One time | |

Provide Add another row and Remove row actions, then save all valid rows together. Do not require the user to open separate Income and Expense forms or manually repeat the save flow.

The saved Money screen must continue to show the conceptual table as Income | Amount | Expense | Amount, with independent sides and totals below. On narrow screens, reflow the input rows vertically while keeping Type, description, amount, schedule, and frequency clear and usable.

Dates may use a sensible shared date control for a batch to keep the flow simple. Recurring entries must still auto-populate applicable future months, and editing a recurring occurrence must create a month-specific override without changing its future default.

42. Current User, Storage, and Advisor Contract

MoneyMonk currently supports a simple local account flow:

- The first screen is Login / Sign up.
- Sign up uses a username and password.
- Passwords must never be stored as plain text; the current local MVP stores a password hash.
- A signed-in session persists across app restarts until the user signs out.
- Money and Loan data must be stored under the signed-in user's namespace.
- Existing pre-account local data may be migrated only to the first account and must not become visible to later accounts.
- Sign out must clear only the active session, not delete the user's saved data.

Local account storage is suitable for the current single-device MVP only. It is not a substitute for production-grade authentication, password recovery, or cross-device synchronization. When multi-device or production multi-user access is required, migrate to Firebase Authentication and user-owned Firestore documents with security rules.

Home is a summary page, not a second detailed dashboard. It may show monthly balance, income, expenses, loan count, outstanding principal, total EMI including extra EMI, and a concise factual priority. Summary sections must drill down to the detailed Money or Loans page when tapped.

The in-app advisor may answer questions using the user's visible MoneyMonk context: income, expenses, recurring entries, balance, loans, EMI, extra EMI, ROI, amortization, and forecast results. Deterministic local answers should remain available without a network. Gemini integration is optional and must:

- Send only the minimum relevant summarized context.
- Never hard-code or persist an API key in source or user data.
- Clearly tell users when a Gemini key/network is required.
- Avoid claiming to provide regulated financial advice.
- Recommend checking loan prepayment charges before suggesting extra payments.

Do not assume a user's ordinary Gemini chat subscription can be accessed automatically. Direct Gemini API access requires an API key or a properly configured secure backend. Never expose a provider secret in a production Flutter client.
