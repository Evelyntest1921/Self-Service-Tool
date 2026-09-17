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
  AND RIGHT(
    jaWait.ActivityExternalKey,
    CHARINDEX('-', REVERSE(jaWait.ActivityExternalKey)) - 1
  ) = RIGHT(
    jaEmail.ActivityExternalKey,
    CHARINDEX('-', REVERSE(jaEmail.ActivityExternalKey)) - 1
  )
WHERE j.JourneyStatus = 'Running'
  AND TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) IS NOT NULL
  AND CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) >= CAST(GETDATE() AS DATE)
  AND CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) < DATEADD(day, 91, CAST(GETDATE() AS DATE))
ORDER BY
  sendTime ASC,
  j.JourneyName ASC,
  jaEmail.ActivityName ASC
