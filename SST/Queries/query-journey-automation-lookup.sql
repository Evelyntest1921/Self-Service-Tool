/*
  Target DE: bd_sst_journey_automation_lookup (overwrite on a schedule in Automation Studio)

  DE fields (align names with this SELECT):
    journeyId               Text 36   Primary Key
    journeyName             Text 200
    automationName          Text 200
    automationGuid          Text 50
    automationCustomerKey   Text 50
    deName                  Text 200
    deId                    Text 50

  Links each journey to an automation that contains a Journey activity step.
  Refresh this DE before relying on Home "Add to builds" automation metadata.
*/
SELECT DISTINCT
  CONVERT(VARCHAR(36), j.JourneyID) AS journeyId,
  j.JourneyName AS journeyName,
  aut.Name AS automationName,
  CONVERT(VARCHAR(50), aut.ObjectID) AS automationGuid,
  aut.CustomerKey AS automationCustomerKey,
  CAST(NULL AS NVARCHAR(200)) AS deName,
  CAST(NULL AS NVARCHAR(50)) AS deId
FROM _Automation aut
INNER JOIN _AutomationActivity aa
  ON aut.ObjectID = aa.ProgramObjectID
INNER JOIN _Journey j
  ON CONVERT(VARCHAR(36), j.JourneyID) = aa.ActivityObjectID
WHERE aut.IsActive = 1
