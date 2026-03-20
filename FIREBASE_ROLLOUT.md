# Firebase Rollout Guide

This project now includes:

- Firestore rules: `firestore.rules`
- Firestore indexes: `firestore.indexes.json`
- Cloud Functions updates in `functions/index.js`
  - `awardRacePointsOnFinish`
  - `settleTimeTrialRooms`
  - `aggregateBehaviorFeaturesDaily` (existing)

## 1. Prerequisites

Install Node.js 20+ and Firebase CLI.

```bash
node -v
firebase --version
```

If Firebase CLI is missing:

```bash
npm install -g firebase-tools
```

Then login:

```bash
firebase login
firebase use <your-project-id>
```

## 2. Deploy

From repository root:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## 3. Smoke Test Checklist

### A) Race points settlement (Cloud Function trigger)

1. Create a live race and let at least 2 participants submit finish times.
2. Set race status to `finished` (normal app flow).
3. Verify:
   - `races/{raceId}/awards/{userId}` is created
   - `users/{userId}.totalPoints` and `monthlyPoints` are incremented
   - team points are incremented when `users/{userId}.teamId` exists

### B) Time trial settlement (scheduled function)

1. Ensure a room has:
   - `periodEnd <= now`
   - participants with `submittedTimeSeconds`
2. Wait for scheduled run (every 30 minutes) or invoke manually in emulator.
3. Verify:
   - `time_trial_rooms/{roomId}/awards/{userId}` is created
   - room has `settledAt`, `settledParticipantCount`, `awardedCount`
   - user/team points increased

### C) Client sync

1. Login on app.
2. Reopen app (or re-enter main flow).
3. Verify:
   - local points display matches remote (`PointService.syncFromRemoteIfNeeded`)
   - ranking reflects Firestore data when available

## 4. Notes

- Client-side direct point awarding for live race/time-trial has been reduced to sample mode only.
- Production awarding path is Cloud Functions.
- Functions use award documents for idempotency to avoid double increment.
