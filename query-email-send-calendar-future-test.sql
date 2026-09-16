/*
  Future / scheduled send exploration for Send Calendar expansion.

  Run each block separately in Query Studio or an Automation Studio query (Preview results).

  Important:
  - _AutomationActivityInstance = Automation Studio step RUN HISTORY (start/end times already executed or running).
    It is NOT a calendar of upcoming Journey email sends. ActivityType 733 = "Journey Builder Event Activity"
    (automation fired a journey entry event). Type 952 is not in public SFMC docs; use Query 1 to see if your BU uses it.
  - Per-contact "Wait Until Date" in Journey Builder does NOT land in system data views as a send datetime.
  - Best DV signal for FUTURE sends: _Job rows with SchedTime / OriginalSchedTime in the future (batch, triggered, some journey jobs).
  - Past sends stay on query-email-send-calendar.sql (_Sent + _Job).
*/

/* --------------------------------------------------------------------------
   Query 1 — Discovery: automation activity types (733, 952, email, wait)
   -------------------------------------------------------------------------- */
SELECT
  a.ActivityType,
  CASE a.ActivityType
    WHEN 42 THEN 'Send Email'
    WHEN 467 THEN 'Wait'
    WHEN 733 THEN 'Journey Builder Event Activity'
    WHEN 749 THEN 'Fire Event'
    WHEN 952 THEN 'Undocumented in SFMC docs (your BU)'
    ELSE 'Other'
  END AS activityTypeLabel,
  a.ActivityName,
  COUNT(*) AS runCount,
  MIN(a.ActivityInstanceStartTime_UTC) AS earliestStartUtc,
  MAX(a.ActivityInstanceStartTime_UTC) AS latestStartUtc
FROM _AutomationActivityInstance a
WHERE a.ActivityInstanceStartTime_UTC >= DATEADD(day, -60, GETDATE())
  AND a.ActivityType IN (42, 467, 733, 749, 952)
GROUP BY
  a.ActivityType,
  a.ActivityName
ORDER BY
  a.ActivityType,
  runCount DESC


/* --------------------------------------------------------------------------
   Query 2 — Primary test: jobs scheduled in the future (+ journey context)
   Use this as the main candidate for a "upcoming sends" calendar slice.
   -------------------------------------------------------------------------- */
SELECT
  CONVERT(VARCHAR(10), CAST(COALESCE(j.OriginalSchedTime, j.SchedTime) AS DATE), 120) AS sendDate,
  COALESCE(j.OriginalSchedTime, j.SchedTime) AS sendTime,
  j.JobID AS jobId,
  j.EmailName AS emailName,
  j.EmailSubject AS emailSubject,
  j.JobStatus AS jobStatus,
  j.SchedTime,
  j.OriginalSchedTime,
  j.PickupTime,
  ja.ActivityName AS journeyActivityName,
  ja.ActivityType AS journeyActivityType,
  jy.JourneyName AS journeyName,
  jy.JourneyID AS journeyId,
  jy.VersionNumber AS versionNumber,
  'scheduled_job' AS sendSource
FROM _Job j
LEFT JOIN _JourneyActivity ja
  ON j.TriggererSendDefinitionObjectID = ja.JourneyActivityObjectID
LEFT JOIN _Journey jy
  ON ja.VersionID = jy.VersionID
WHERE COALESCE(j.OriginalSchedTime, j.SchedTime) >= CAST(GETDATE() AS DATE)
  AND COALESCE(j.OriginalSchedTime, j.SchedTime) < DATEADD(day, 91, CAST(GETDATE() AS DATE))
  AND j.JobStatus NOT IN ('Deleted', 'Canceled', 'Error')
ORDER BY
  sendTime ASC,
  j.JobID ASC


/* --------------------------------------------------------------------------
   Query 3 — Journey email + wait activities (structure only, no future datetime)
   Helps validate names like "Email" / "Wait Until Date" on active journey versions.
   -------------------------------------------------------------------------- */
SELECT
  jy.JourneyName,
  jy.JourneyID,
  jy.VersionNumber,
  ja.ActivityName,
  ja.ActivityType,
  ja.JourneyActivityObjectID
FROM _Journey jy
INNER JOIN _JourneyActivity ja
  ON jy.VersionID = ja.VersionID
WHERE ja.ActivityType IN ('EMAIL', 'EMAILV2', 'WAIT')
   OR ja.ActivityName LIKE '%Email%'
   OR ja.ActivityName LIKE '%Wait%'
ORDER BY
  jy.JourneyName,
  ja.ActivityName
