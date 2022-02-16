local AlmaApiInternal = {};
AlmaApiInternal.ApiUrl = nil;
AlmaApiInternal.ApiKey = nil;


local types = {};
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager");
types["System.Net.WebClient"] = luanet.import_type("System.Net.WebClient");
types["System.Text.Encoding"] = luanet.import_type("System.Text.Encoding");
types["System.Xml.XmlTextReader"] = luanet.import_type("System.Xml.XmlTextReader");
types["System.Xml.XmlDocument"] = luanet.import_type("System.Xml.XmlDocument");

-- Create a logger
local log = types["log4net.LogManager"].GetLogger(rootLogger .. ".AlmaApi");

AlmaApi = AlmaApiInternal;


local function RetrieveHoldingsList( mmsId )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .."bibs/"..
    Utility.URLEncode(mmsId) .."/holdings";
    log:DebugFormat("Request URL: {0}", requestUrl);
    local response = WebClient.GetRequest(requestUrl, headers);
    log:DebugFormat("response = {0}", response);

    return WebClient.ReadResponse(response);
end

local function RetrieveBibs( mmsId )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .. "bibs?&mms_id=" .. Utility.URLEncode(mmsId);
    log:DebugFormat("Request URL: {0}", requestUrl);

    local response = WebClient.GetRequest(requestUrl, headers);
    log:DebugFormat("response = {0}", response);

    return WebClient.ReadResponse(response);
end

local function RetrieveItemByBarcode( barcode )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .. "items?item_barcode=" .. Utility.URLEncode(barcode);
    log:DebugFormat("Request URL: {0}", requestUrl);

    local response = WebClient.GetRequest(requestUrl, headers);
    log:DebugFormat("response = {0}", response);

    return WebClient.ReadResponse(response);
end

local function PlaceHoldByItemPID( mms_id, holding_id, item_pid, user, pickup_location )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .. "bibs/"..mms_id.."/holdings/"..holding_id.."/items/"..item_pid.."/requests?user_id_type=all_unique&allow_same_request=true&user_id="..Utility.URLEncode(user);
    log:DebugFormat("Request URL: {0}", requestUrl);
    local body = [[
<user_request>
    <request_type>HOLD</request_type>
    <pickup_location_type>LIBRARY</pickup_location_type>
    <pickup_location_library>]] .. pickup_location ..[[</pickup_location_library>
    <pickup_location_circulation_desk>
        DEFAULT_CIRC_DESK
    </pickup_location_circulation_desk>
</user_request>]]
    local response = WebClient.PostRequest(requestUrl, headers, body);
    log:DebugFormat("response = {0}", response)

    return WebClient.ReadResponse(response);

end

-- Exports
AlmaApi.RetrieveHoldingsList = RetrieveHoldingsList;
AlmaApi.RetrieveBibs = RetrieveBibs;
AlmaApi.RetrieveItemByBarcode = RetrieveItemByBarcode;
AlmaApi.PlaceHoldByItemPID = PlaceHoldByItemPID;