# Quick Send emails (SST)

Content Builder emails created from the Quick Send hub (`SST - Surveys/email-hub`) and the template-slot test page.

## Content Builder folder

New emails are filed under **SST Quick Send Emails**. On first create, the hub calls the Categories API to create that folder if it does not exist yet.

Default parent folder category ID: **58374** (same SST email area used elsewhere in this repo). Override in `SFMC_TEMPLATES` for `User=Admin`:

| Field | Purpose |
| --- | --- |
| `Quick_Send_Email_Category_ID` | Fixed folder ID (recommended after first create — skips list/create on every send) |
| `Quick_Send_Email_Parent_Category_ID` | Parent folder when auto-creating **SST Quick Send Emails** |

## Related assets

- Hub UI: `SST - Surveys/email-hub`
- Slot create test: `template-slot-email-test`
- Template IDs: `SFMC_TEMPLATES` (`LG_BG_Header_Email_BD_Template`, etc.)
