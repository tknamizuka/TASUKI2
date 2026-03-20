"use strict";

const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");

admin.initializeApp();
const db = admin.firestore();

const EVENT_NAMES = {
  run: new Set(["run_tracking_start", "run_tracking_stop", "race_finish_submitted", "time_trial_submitted"]),
  social: new Set(["message_sent", "conversation_created", "practice_chat_participant_added"]),
};

function yyyymmdd(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

function startOfUtcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, 0, 0));
}

function endOfUtcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999));
}

function startOfUtcMinusDays(date, days) {
  const start = startOfUtcDay(date);
  return new Date(start.getTime() - days * 24 * 60 * 60 * 1000);
}

function normalizeHour(tsLike) {
  if (!tsLike) return null;
  if (typeof tsLike.toDate === "function") {
    return tsLike.toDate().getHours();
  }
  const d = new Date(tsLike);
  if (Number.isNaN(d.getTime())) return null;
  return d.getHours();
}

function topHourByHistogram(hist) {
  let bestHour = null;
  let bestCount = -1;
  for (let h = 0; h < 24; h += 1) {
    const count = hist[h] || 0;
    if (count > bestCount) {
      bestCount = count;
      bestHour = h;
    }
  }
  return bestHour;
}

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function median(numbers) {
  if (!numbers.length) return null;
  const sorted = numbers.slice().sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid];
}

const RACE_POSITION_POINTS = [500, 400, 320, 260, 212, 170, 136, 109, 87, 70];
const RACE_FINISH_BONUS = 100;
const RACE_PARTICIPATION_BONUS = 50;
const TIME_TRIAL_POINTS_TABLE = [
  100, 90, 81, 73, 66, 59, 53, 48, 43, 39,
  35, 31, 28, 25, 22, 20, 18, 16, 14, 12,
];

function racePointsByRank(rank) {
  const positionPoint = rank <= RACE_POSITION_POINTS.length ? RACE_POSITION_POINTS[rank - 1] : 0;
  return positionPoint + RACE_FINISH_BONUS + RACE_PARTICIPATION_BONUS;
}

function timeTrialPointsByRank(rank) {
  return rank <= TIME_TRIAL_POINTS_TABLE.length ? TIME_TRIAL_POINTS_TABLE[rank - 1] : 0;
}

async function awardRacePointsForParticipant({
  raceId,
  participantId,
  participantName,
  rank,
  amount,
}) {
  const awardRef = db
      .collection("races")
      .doc(raceId)
      .collection("awards")
      .doc(participantId);
  const userRef = db.collection("users").doc(participantId);

  return db.runTransaction(async (tx) => {
    const awardSnap = await tx.get(awardRef);
    if (awardSnap.exists) {
      return false;
    }

    tx.set(awardRef, {
      userId: participantId,
      userName: participantName,
      rank,
      points: amount,
      awardedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    tx.set(userRef, {
      totalPoints: admin.firestore.FieldValue.increment(amount),
      monthlyPoints: admin.firestore.FieldValue.increment(amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    const userSnap = await tx.get(userRef);
    const teamId = userSnap.data()?.teamId;
    if (typeof teamId === "string" && teamId.length > 0) {
      const teamRef = db.collection("teams").doc(teamId);
      tx.set(teamRef, {
        teamTotalPoints: admin.firestore.FieldValue.increment(amount),
        teamMonthlyPoints: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    return true;
  });
}

exports.awardRacePointsOnFinish = onDocumentUpdated(
    {
      document: "races/{raceId}",
      region: "asia-northeast1",
      memory: "512MiB",
    },
    async (event) => {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      const raceId = event.params.raceId;
      if (!before || !after || !raceId) {
        return;
      }
      if (before.status === "finished" || after.status !== "finished") {
        return;
      }

      logger.info("race points awarding started", {raceId});

      const participantsSnap = await db
          .collection("races")
          .doc(raceId)
          .collection("participants")
          .get();
      const finishers = participantsSnap.docs
          .map((doc) => ({id: doc.id, ...doc.data()}))
          .filter((p) => typeof p.finishTimeSeconds === "number" && p.finishTimeSeconds > 0)
          .sort((a, b) => a.finishTimeSeconds - b.finishTimeSeconds);

      let awardedCount = 0;
      for (let i = 0; i < finishers.length; i += 1) {
        const rank = i + 1;
        const p = finishers[i];
        const amount = racePointsByRank(rank);
        const awarded = await awardRacePointsForParticipant({
          raceId,
          participantId: p.id,
          participantName: p.name || "Runner",
          rank,
          amount,
        });
        if (awarded) {
          awardedCount += 1;
        }
      }

      logger.info("race points awarding completed", {
        raceId,
        finishers: finishers.length,
        awardedCount,
      });
    },
);

async function awardTimeTrialPointsForParticipant({
  roomId,
  participantId,
  participantName,
  rank,
  amount,
}) {
  const awardRef = db
      .collection("time_trial_rooms")
      .doc(roomId)
      .collection("awards")
      .doc(participantId);
  const userRef = db.collection("users").doc(participantId);

  return db.runTransaction(async (tx) => {
    const awardSnap = await tx.get(awardRef);
    if (awardSnap.exists) {
      return false;
    }

    tx.set(awardRef, {
      userId: participantId,
      userName: participantName,
      rank,
      points: amount,
      awardedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    tx.set(userRef, {
      totalPoints: admin.firestore.FieldValue.increment(amount),
      monthlyPoints: admin.firestore.FieldValue.increment(amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    const userSnap = await tx.get(userRef);
    const teamId = userSnap.data()?.teamId;
    if (typeof teamId === "string" && teamId.length > 0) {
      const teamRef = db.collection("teams").doc(teamId);
      tx.set(teamRef, {
        teamTotalPoints: admin.firestore.FieldValue.increment(amount),
        teamMonthlyPoints: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    return true;
  });
}

exports.settleTimeTrialRooms = onSchedule(
    {
      schedule: "every 30 minutes",
      timeZone: "Asia/Tokyo",
      region: "asia-northeast1",
      memory: "512MiB",
    },
    async () => {
      const now = admin.firestore.Timestamp.fromDate(new Date());
      const roomSnap = await db.collection("time_trial_rooms")
          .where("periodEnd", "<=", now)
          .limit(50)
          .get();
      if (roomSnap.empty) {
        return;
      }

      logger.info("time trial settlement started", {rooms: roomSnap.size});

      for (const roomDoc of roomSnap.docs) {
        const roomId = roomDoc.id;
        const roomData = roomDoc.data();
        if (roomData.settledAt) {
          continue;
        }
        try {
          const participantsSnap = await db.collection("time_trial_rooms")
              .doc(roomId)
              .collection("participants")
              .get();
          const finishers = participantsSnap.docs
              .map((doc) => ({id: doc.id, ...doc.data()}))
              .filter((p) => typeof p.submittedTimeSeconds === "number" && p.submittedTimeSeconds > 0)
              .sort((a, b) => a.submittedTimeSeconds - b.submittedTimeSeconds)
              .slice(0, 20);

          let awardedCount = 0;
          for (let i = 0; i < finishers.length; i += 1) {
            const rank = i + 1;
            const p = finishers[i];
            const amount = timeTrialPointsByRank(rank);
            const awarded = await awardTimeTrialPointsForParticipant({
              roomId,
              participantId: p.id,
              participantName: p.name || "Runner",
              rank,
              amount,
            });
            if (awarded) {
              awardedCount += 1;
            }
          }

          await db.collection("time_trial_rooms").doc(roomId).set({
            settledAt: admin.firestore.FieldValue.serverTimestamp(),
            settledParticipantCount: finishers.length,
            awardedCount,
          }, {merge: true});

          logger.info("time trial room settled", {
            roomId,
            finishers: finishers.length,
            awardedCount,
          });
        } catch (error) {
          logger.error("time trial settlement failed", {
            roomId,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
    },
);

exports.aggregateBehaviorFeaturesDaily = onSchedule(
    {
      schedule: "every day 02:10",
      timeZone: "Asia/Tokyo",
      region: "asia-northeast1",
      memory: "512MiB",
    },
    async () => {
      const now = new Date();
      const todayUtc = startOfUtcDay(now);
      const fourteenDaysAgoUtc = startOfUtcMinusDays(now, 13);
      const sevenDaysAgoUtc = startOfUtcMinusDays(now, 6);
      const targetDateKey = yyyymmdd(new Date(todayUtc.getTime() - 24 * 60 * 60 * 1000));

      logger.info("behavior aggregation started", {targetDateKey});

      const usersSnap = await db.collection("users").get();
      logger.info("users loaded", {count: usersSnap.size});

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        try {
          const eventsSnap = await db
              .collection("users")
              .doc(userId)
              .collection("reality_events")
              .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(fourteenDaysAgoUtc))
              .where("timestamp", "<=", admin.firestore.Timestamp.fromDate(endOfUtcDay(now)))
              .get();

          let weeklyRunCount = 0;
          let previousWeeklyRunCount = 0;
          let socialEventCount = 0;
          const activeDays = new Set();
          const hourHistogram = Array(24).fill(0);
          const weekdayHistogram = Array(7).fill(0); // Sun=0 ... Sat=6
          const messageTimestamps = [];
          const currentWeeklyDayCounts = Array(7).fill(0);

          for (const eventDoc of eventsSnap.docs) {
            const data = eventDoc.data();
            const eventName = data.event_name || "";
            const timestamp = data.timestamp;
            const eventDate = typeof timestamp?.toDate === "function" ? timestamp.toDate() : null;
            if (eventDate) {
              activeDays.add(yyyymmdd(eventDate));
              const weekday = eventDate.getDay();
              weekdayHistogram[weekday] += 1;
              if (eventDate >= sevenDaysAgoUtc) {
                currentWeeklyDayCounts[weekday] += 1;
              }
            }

            const hour = normalizeHour(timestamp);
            if (hour !== null && hour >= 0 && hour <= 23) {
              hourHistogram[hour] += 1;
            }

            if (EVENT_NAMES.run.has(eventName)) {
              if (eventDate && eventDate >= sevenDaysAgoUtc) {
                weeklyRunCount += 1;
              } else {
                previousWeeklyRunCount += 1;
              }
            }
            if (EVENT_NAMES.social.has(eventName)) {
              socialEventCount += 1;
            }
            if (eventName === "message_sent" && eventDate) {
              messageTimestamps.push(eventDate.getTime());
            }
          }

          const runTrendDelta = weeklyRunCount - previousWeeklyRunCount;
          const totalEvents = weekdayHistogram.reduce((sum, count) => sum + count, 0);
          const weekendEvents = weekdayHistogram[0] + weekdayHistogram[6];
          const weekendActivityRatio = totalEvents > 0 ? weekendEvents / totalEvents : 0;
          const activeWeekdayCount = currentWeeklyDayCounts.filter((count) => count > 0).length;
          const routineSpreadScore = clamp01(activeWeekdayCount / 7);
          const messageIntervalsSec = [];
          if (messageTimestamps.length > 1) {
            const sorted = messageTimestamps.slice().sort((a, b) => a - b);
            for (let i = 1; i < sorted.length; i += 1) {
              const sec = (sorted[i] - sorted[i - 1]) / 1000;
              if (sec > 0 && sec < 24 * 60 * 60) {
                messageIntervalsSec.push(sec);
              }
            }
          }
          const medianMessageIntervalSec = median(messageIntervalsSec);

          // 0..1 に正規化（上限クリップ）
          const consistencyScore = clamp01(activeDays.size / 7);
          const socialActivityScore = clamp01(socialEventCount / 30);
          const behaviorShiftScore = clamp01(Math.abs(runTrendDelta) / 10);
          const topActiveHour = topHourByHistogram(hourHistogram);

          const feature = {
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            weeklyRunCount,
            weeklyRunTrendDelta: runTrendDelta,
            socialActivityScore,
            consistencyScore,
            weekendActivityRatio,
            routineSpreadScore,
            behaviorShiftScore,
            medianMessageIntervalSec,
            topActiveHour,
            sourceEventCount: eventsSnap.size,
            windowDays: 14,
          };

          await db
              .collection("users")
              .doc(userId)
              .collection("behavior_features")
              .doc(targetDateKey)
              .set(feature, {merge: true});
        } catch (error) {
          logger.error("behavior aggregation failed for user", {
            userId,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      logger.info("behavior aggregation completed", {targetDateKey});
    },
);
