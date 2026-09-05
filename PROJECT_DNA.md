# MoneyMonk Project DNA

## Identity

- Product: MoneyMonk
- Stack: Flutter, Dart, Firebase Authentication, Cloud Firestore, Firebase Hosting
- Firebase project: `moneymonk-d5605`
- Core user experience: open the app, see money, add or review money and loans
- Primary product areas: Money and Loans

## Data Ownership

The cloud ownership chain is:

`MoneyMonk account -> Firebase Auth UID -> users/{uid}`

User-owned data is stored below that UID:

- `users/{uid}/money/{entryId}`
- `users/{uid}/loans/{loanId}`
- `users/{uid}/profile/info`

Every normal cloud read, write, update, and delete must resolve the UID from the authenticated Firebase user. A username-derived UID is permitted only for local/offline compatibility and must never be used for an authenticated cloud operation.

Firestore rules must require both:

- an authenticated request
- `request.auth.uid == {uid}`

Logging out must sign out Firebase Auth, remove the authenticated app session, and prevent the previous user's private records from being displayed in the next account session.

## Persistence Rules

- Local storage is a cache and offline fallback, not a cross-account data source.
- Recovery may restore only the active account's own local namespace.
- Global backups and another account's keys must never be used to populate a different account.
- Delete All Data must delete only the authenticated user's money and loan documents, then clear that user's local data and session state.
- Financial calculations use integer paise or another exact representation where practical.

## Scope Guardrails

Do not add analytics, banking integrations, subscriptions, paid services, admin systems, AI chat, or unrelated financial modules without an explicit product request. Do not add Firebase services beyond what the implemented product needs.

## Pre-Deployment Verification

Run all of the following from the repository root:

```text
flutter analyze
flutter test
flutter build web --release
```

Before deployment, inspect and test:

1. UID ownership on every Firestore operation.
2. Authenticated and unauthenticated Firestore rule behavior.
3. Cross-user access denial.
4. Sign-out and account-switch data isolation.
5. Delete All Data isolation.
6. Offline fallback and recovery behavior.
7. Financial calculation regression coverage.
8. Firebase billing status in the Firebase or Google Cloud console. Billing status cannot be proven from source code alone.
9. The repository for paid-service dependencies, payment APIs, and newly introduced secrets.

Current verification note: local financial storage is UID-scoped, global financial keys are no longer read or written by production code, and empty accounts remain empty. Legacy/global keys may remain on a device as unassigned data, but they are not automatically imported. Keep the account-isolation regression tests in the release gate.
