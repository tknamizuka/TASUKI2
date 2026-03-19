"use strict";

const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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
