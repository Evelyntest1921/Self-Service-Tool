SELECT
  CONVERT(VARCHAR(10), CAST(s.EventDate AS DATE), 120) + '|' + CONVERT(VARCHAR(20), j.JobID) AS calendarKey,
  CAST(s.EventDate AS DATE) AS sendDate,
  CONVERT(VARCHAR(20), j.JobID) AS jobId,
  j.EmailName AS emailName,
  j.EmailSubject AS emailSubject,
  MIN(s.EventDate) AS sendTime,
  COUNT(*) AS recipients,
  MAX(jy.JourneyID) AS journeyId,
  MAX(jy.JourneyName) AS journeyName,
  MAX(jy.VersionNumber) AS versionNumber
FROM _Sent s
INNER JOIN _Job j
  ON j.JobID = s.JobID
LEFT JOIN _JourneyActivity ja
  ON s.TriggererSendDefinitionObjectID = ja.JourneyActivityObjectID
LEFT JOIN _Journey jy
  ON ja.VersionID = jy.VersionID
WHERE s.EventDate >= DATEADD(day, -90, CAST(GETDATE() AS DATE))
  AND s.EventDate < DATEADD(day, 1, CAST(GETDATE() AS DATE))
GROUP BY
  CAST(s.EventDate AS DATE),
  j.JobID,
  j.EmailName,
  j.EmailSubject

UNION ALL

SELECT
  CONVERT(VARCHAR(36), j.JourneyID) + '|' + CONVERT(VARCHAR(10), j.VersionNumber) + '|' + jaEmail.ActivityExternalKey AS calendarKey,
  CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) AS sendDate,
  '' AS jobId,
  jaEmail.ActivityName AS emailName,
  '' AS emailSubject,
  TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS sendTime,
  0 AS recipients,
  j.JourneyID AS journeyId,
  j.JourneyName AS journeyName,
  j.VersionNumber AS versionNumber
FROM _Journey j
INNER JOIN _JourneyActivity jaWait
  ON jaWait.VersionID = j.VersionID
  AND jaWait.ActivityExternalKey LIKE 'WAITUNTILSPECIFICDATE-%'
INNER JOIN _JourneyActivity jaEmail
  ON jaEmail.VersionID = j.VersionID
  AND jaEmail.ActivityType IN ('EMAILV2', 'EMAIL')
  AND (
    jaEmail.ActivityExternalKey LIKE 'EMAILV2-%'
    OR jaEmail.ActivityExternalKey LIKE 'EMAIL-%'
  )
  AND PARSENAME(REPLACE(jaWait.ActivityExternalKey, '-', '.'), 1)
    = PARSENAME(REPLACE(jaEmail.ActivityExternalKey, '-', '.'), 1)
WHERE j.JourneyStatus = 'Running'
  AND TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) IS NOT NULL
  AND CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) >= CAST(GETDATE() AS DATE)
  AND CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) < DATEADD(day, 91, CAST(GETDATE() AS DATE))
