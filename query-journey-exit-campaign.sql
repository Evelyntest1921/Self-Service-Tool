SELECT
  b.batchId + '|' + cm.LeadOrContactId AS [key],
  cm.LeadOrContactId AS subscriberKey,
  b.journeyName AS journeyName,
  b.journeyID AS journeyId,
  b.batchId AS batchID,
  'Pending' AS [Status]
FROM bd_sst_journey_exit_batch b
INNER JOIN CampaignMember_Salesforce_2 cm
  ON (
    cm.CampaignId = b.campaignId
    OR LEFT(cm.CampaignId, 15) = LEFT(b.campaignId, 15)
  )
  AND LOWER(cm.[Status]) = LOWER(b.memberStatus)
WHERE LOWER(b.[status]) = 'pending'
  AND LOWER(b.sourceType) = 'campaign'
  AND cm.LeadOrContactId IS NOT NULL
  AND cm.LeadOrContactId <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bd_sst_journey_exit e
    WHERE e.[key] = b.batchId + '|' + cm.LeadOrContactId
  )
