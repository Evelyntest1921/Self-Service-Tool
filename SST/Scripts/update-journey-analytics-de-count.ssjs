<script runat="server">
Platform.Load("Core", "1");

/* Automation Studio Script Activity. Run in the DE's business unit.
 * Credentials are read from SFMC_AUTH, User = Admin, matching stack-de-test.
 * Required package scopes: Journeys Read and Data Extensions Read/Write.
 * deModifiedDate means LAST SUCCESSFUL COUNT REFRESH in this script.
 * It does NOT mean the source DE's metadata ModifiedDate.
 */
var CFG = {
    analyticsKey: "REPLACE_WITH_BD_JOURNEY_ANALYTICS_EXTERNAL_KEY",
    authDEKey: "SFMC_AUTH",
    authUser: "Admin",
    journeyId: "journeyId",
    journeyModified: "journeyModifiedDate",
    refreshed: "deModifiedDate",
    count: "deCount",
    deName: "deName", // Required Text column; change to your actual column name.
    deId: "deId",     // Required Text(36+) column; stores the source DE ObjectID.
    version: "",      // Set to your version column, e.g. "versionNumber", if present.
    primaryKeys: ["journeyId"] // All primary-key columns identifying ONE analytics row.
};

var api = new Script.Util.WSProxy();
var analytics = DataExtension.Init(CFG.analyticsKey);
var token = null;
var tokenUntil = 0;
var restBase = "";
var summary = { scanned: 0, eligible: 0, updated: 0, failed: 0 };

function empty(v) {
    return v === null || typeof v === "undefined" || String(v) === "";
}

function jsonRequest(method, url, payload, bearer) {
    var req = new Script.Util.HttpRequest(url);
    req.method = method;
    req.contentType = "application/json";
    req.continueOnError = true;
    req.emptyContentHandling = 0;
    req.retries = 2;
    if (bearer) req.setHeader("Authorization", "Bearer " + bearer);
    if (payload) req.postData = Stringify(payload);
    var res = req.send();
    if (Number(res.statusCode) < 200 || Number(res.statusCode) >= 300) {
        // Do not print response bodies: authentication responses can contain secrets.
        throw new Error("HTTP " + res.statusCode + " during " + method);
    }
    return Platform.Function.ParseJSON(String(res.content));
}

function getRest(path) {
    if (!token || new Date().getTime() >= tokenUntil) {
        var authRows = DataExtension.Init(CFG.authDEKey).Rows.Lookup(["User"], [CFG.authUser]);
        if (!authRows || authRows.length < 1) throw new Error("No SFMC_AUTH Admin row");
        var authRow = authRows[0];
        var clientId = String(authRow.clientId || "");
        var clientSecret = String(authRow.clientSecret || "");
        var subdomain = String(authRow.subdomain || "");
        var mid = String(authRow.accountId || "");
        if (!clientId || !clientSecret || !subdomain) {
            throw new Error("Missing SFMC_AUTH credentials");
        }
        var authBase = "https://" + subdomain + ".auth.marketingcloudapis.com";
        var authPayload = {
            grant_type: "client_credentials",
            client_id: clientId,
            client_secret: clientSecret
        };
        if (mid) authPayload.account_id = mid;
        var auth = jsonRequest("POST", authBase + "/v2/token", authPayload, null);
        if (!auth.access_token || !auth.rest_instance_url) {
            throw new Error("Authentication response missing token or REST URL");
        }
        token = auth.access_token;
        restBase = String(auth.rest_instance_url).replace(/\/$/, "");
        tokenUntil = new Date().getTime() + (Number(auth.expires_in) - 60) * 1000;
    }
    return jsonRequest("GET", restBase + path, null, token);
}

function dateMillis(value) {
    var ms = new Date(value).getTime();
    if (isNaN(ms)) throw new Error("Invalid date: " + value);
    return ms;
}

function processRow(row) {
    summary.scanned++;
    // SOAP filters cannot compare one DE column with another column.
    // Evaluate the exact condition in SSJS instead.
    if (!empty(row[CFG.refreshed])) {
        if (empty(row[CFG.journeyModified])) return;
        if (dateMillis(row[CFG.journeyModified]) <= dateMillis(row[CFG.refreshed])) return;
    }
    summary.eligible++;
    if (empty(row[CFG.journeyId])) throw new Error("Missing journey ID");

    // Capture refresh start, so modifications during processing remain eligible.
    var refreshStarted = Platform.Function.Now();
    var path = "/interaction/v1/interactions/" + encodeURIComponent(row[CFG.journeyId]);
    if (CFG.version && !empty(row[CFG.version])) {
        path += "?versionNumber=" + encodeURIComponent(row[CFG.version]);
    }
    var journey = getRest(path);
    var triggers = journey.triggers || [];
    if (triggers.length !== 1) throw new Error("Expected one entry trigger");
    var trigger = triggers[0];
    var meta = trigger.metaData || {};
    var args = trigger.arguments || {};
    var eventId = meta.eventDefinitionId || args.eventDefinitionId;
    var eventKey = meta.eventDefinitionKey || args.eventDefinitionKey;
    if (!eventId && !eventKey) throw new Error("Entry trigger has no event definition");

    var eventPath = "/interaction/v1/eventDefinitions/" +
        (eventId ? encodeURIComponent(eventId) : "key:" + encodeURIComponent(eventKey));
    var event = getRest(eventPath);
    var objectId = event.dataExtensionId || event.dataExtensionID;
    if (!objectId) throw new Error("Entry source has no associated data extension");

    var deResult = api.retrieve("DataExtension", ["ObjectID", "Name", "CustomerKey"], {
        Property: "ObjectID", SimpleOperator: "equals", Value: objectId
    });
    if (!deResult || deResult.Status !== "OK" || !deResult.Results ||
        deResult.Results.length !== 1) {
        throw new Error("Cannot resolve entry DE in this business unit");
    }
    var source = deResult.Results[0];
    // DataExtensionRowCount takes a DE NAME. Pass via a variable to avoid
    // inserting the DE name into executable AMPscript.
    Platform.Variable.SetValue("@jaSourceDEName", source.Name);
    var count = Number(Platform.Function.TreatAsContent(
        "%%=DataExtensionRowCount(@jaSourceDEName)=%%"
    ));
    if (isNaN(count) || count < 0 || Math.floor(count) !== count) {
        throw new Error("Invalid source DE row count");
    }

    var values = {};
    values[CFG.count] = count;
    values[CFG.deName] = source.Name;
    values[CFG.deId] = source.ObjectID;
    values[CFG.refreshed] = refreshStarted;
    var keys = [];
    for (var k = 0; k < CFG.primaryKeys.length; k++) {
        if (empty(row[CFG.primaryKeys[k]])) throw new Error("Missing primary key");
        keys.push(row[CFG.primaryKeys[k]]);
    }
    if (Number(analytics.Rows.Update(values, CFG.primaryKeys, keys)) !== 1) {
        throw new Error("Update did not affect exactly one analytics row");
    }
    summary.updated++;
}

var columns = [CFG.journeyId, CFG.journeyModified, CFG.refreshed];
if (CFG.version) columns.push(CFG.version);
for (var p = 0; p < CFG.primaryKeys.length; p++) {
    var found = false;
    for (var c = 0; c < columns.length; c++) {
        if (columns[c] === CFG.primaryKeys[p]) found = true;
    }
    if (!found) columns.push(CFG.primaryKeys[p]);
}

var objectType = "DataExtensionObject[" + CFG.analyticsKey + "]";
var page = api.retrieve(objectType, columns);
while (true) {
    if (!page || page.Status !== "OK" || !page.Results) {
        throw new Error("Could not retrieve analytics rows");
    }
    for (var i = 0; i < page.Results.length; i++) {
        var row = {};
        var props = page.Results[i].Properties;
        for (var j = 0; j < props.length; j++) row[props[j].Name] = props[j].Value;
        try {
            processRow(row);
        } catch (err) {
            summary.failed++;
            Write(Stringify({ journeyId: row[CFG.journeyId], error: String(err) }) + "\n");
        }
    }
    if (!page.HasMoreRows) break;
    page = api.getNextBatch(objectType, page.RequestID);
}
Write(Stringify(summary));
if (summary.failed > 0) throw new Error(summary.failed + " analytics rows failed; see output");
</script>
