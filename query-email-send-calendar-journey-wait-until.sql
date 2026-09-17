SELECT
  CONVERT(VARCHAR(36), j.JourneyID) + '|' + CONVERT(VARCHAR(10), j.VersionNumber) + '|' + jaEmail.ActivityExternalKey AS calendarKey,
  CAST(TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS DATE) AS sendDate,
  TRY_CONVERT(DATETIME, jaWait.ActivityName, 107) AS sendTime,
  jaEmail.ActivityName AS emailName,
  CAST(NULL AS VARCHAR(500)) AS emailSubject,
  CAST(0 AS INT) AS recipients,
  j.JourneyID AS journeyId,
  j.JourneyName AS journeyName,
  j.VersionNumber AS versionNumber,
  jaWait.ActivityName AS waitDateText,
  jaWait.ActivityExternalKey AS waitActivityKey,
  jaEmail.ActivityExternalKey AS emailActivityKey,
  jaEmail.JourneyActivityObjectID AS journeyActivityObjectId,
  'journey_wait_until' AS sendSource
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
ORDER BY
  sendTime ASC,
  j.JourneyName ASC,
  jaEmail.ActivityName ASC
