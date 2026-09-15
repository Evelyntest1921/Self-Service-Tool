SELECT
  CONVERT(VARCHAR(10), CAST(s.EventDate AS DATE), 120) + '|' + CONVERT(VARCHAR(20), j.JobID) AS calendarKey,
  CAST(s.EventDate AS DATE) AS sendDate,
  j.JobID AS jobId,
  j.EmailName AS emailName,
  j.EmailSubject AS emailSubject,
  MIN(s.EventDate) AS sendTime,
  COUNT(*) AS recipients
FROM _Sent s
INNER JOIN _Job j
  ON j.JobID = s.JobID
WHERE s.EventDate >= DATEADD(day, -90, CAST(GETDATE() AS DATE))
  AND s.EventDate < DATEADD(day, 1, CAST(GETDATE() AS DATE))
GROUP BY
  CAST(s.EventDate AS DATE),
  j.JobID,
  j.EmailName,
  j.EmailSubject
