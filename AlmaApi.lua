local AlmaApiInternal = {}
AlmaApiInternal.ApiUrl = nil
AlmaApiInternal.ApiKey = nil


local types = {}
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager")
types["System.Net.WebClient"] = luanet.import_type("System.Net.WebClient")
types["System.Text.Encoding"] = luanet.import_type("System.Text.Encoding")
types["System.Xml.XmlTextReader"] = luanet.import_type("System.Xml.XmlTextReader")
types["System.Xml.XmlDocument"] = luanet.import_type("System.Xml.XmlDocument")

-- Create a logger
local log = types["log4net.LogManager"].GetLogger(rootLogger .. ".AlmaApi")

AlmaApi = AlmaApiInternal


local function RetrieveHoldingsList( mmsId )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .."bibs/"..
    Utility.URLEncode(mmsId) .."/holdings"
    log:DebugFormat("Request URL: {0}", requestUrl)
    local response = WebClient.GetRequest(requestUrl, headers)
    log:DebugFormat("response = {0}", response)

    return WebClient.ReadResponse(response)
end

local function RetrieveBibs( mmsId )
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .. "bibs?&mms_id=" .. Utility.URLEncode(mmsId);
    log:DebugFormat("Request URL: {0}", requestUrl)

    local response = WebClient.GetRequest(requestUrl, headers)
    log:DebugFormat("response = {0}", response)

    return WebClient.ReadResponse(response)
end

local function RetrieveItemByBarcode( barcode )
    
    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey}
    local requestUrl = AlmaApiInternal.ApiUrl .. "items?item_barcode=" .. Utility.URLEncode(barcode);
    log:DebugFormat("Request URL: {0}", requestUrl)

    local success, response = pcall(WebClient.GetRequest, requestUrl, headers)
    if success then
        return WebClient.ReadResponse(response)
    else
        log:Debug("call to webClient.GetRequest was NOT successful")
        interfaceMngr:ShowMessage("lookup failed: ".. WebClient.ReadResponse(response):GetElementsByTagName("errorMessage"):Item(0).InnerText, "ERROR")
        return error("some error")
    end
    
end

local function PlaceHoldByItemPID(mms_id, holding_id, item_pid, user, pickup_location, office_delivery)
    
    -- if office delivery is selected, pickup_location is ignored.
    local pickup_location_type =""
    if office_delivery then
        pickup_location_type = "USER_WORK_ADDRESS"
    else
        pickup_location_type = "LIBRARY"
    end

    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey}
    local requestUrl = AlmaApiInternal.ApiUrl .. "bibs/"..mms_id.."/holdings/"..holding_id.."/items/"..item_pid.."/requests?user_id_type=all_unique&allow_same_request=true&user_id="..Utility.URLEncode(user);
    log:DebugFormat("Request URL: {0}", requestUrl)
    local body = [[
<user_request>
    <request_type>HOLD</request_type>
    <pickup_location_type>]]..pickup_location_type..[[</pickup_location_type>
    <pickup_location_library>]] .. pickup_location ..[[</pickup_location_library>
    <pickup_location_circulation_desk>DEFAULT_CIRC_DESK</pickup_location_circulation_desk>
</user_request>]]
    log:DebugFormat("request body: {0}", body);
    local success, response = pcall(WebClient.PostRequest, requestUrl, headers, body)
    log:DebugFormat("response = {0}", response);
    log:DebugFormat("success: {0}", success)
    if success then
        -- we expect to get an xml document as the response object in a successful hold attempt
        log:Debug("call to webClient.PostRequest was successful")
        interfaceMngr:ShowMessage("Hold placed for user: ".. WebClient.ReadResponse(response):GetElementsByTagName("user_primary_id"):Item(0).InnerText, "Place LSA Hold")
        return
    else
        -- If the hold attempt fails, we expect the error object to contain a string of xml from the Alma server.
        -- Convert that string to an xml document and throw an error.
        -- show an error message and throw an error
        log:Debug("call to webClient.PostRequest was NOT successful")
        local error_message = WebClient.ReadResponse(response):GetElementsByTagName("errorMessage"):Item(0).InnerText
        interfaceMngr:ShowMessage("Hold failed: ".. error_message, "ERROR")
        error(error_message)
    end
end

local function PlaceHoldByMmsId(mms_id, user, pickup_location, office_delivery)
    
    -- if office delivery is selected, pickup_location is ignored.
    local pickup_location_type =""
    if office_delivery then
        pickup_location_type = "USER_WORK_ADDRESS"
    else
        pickup_location_type = "LIBRARY"
    end

    local headers = {"Accept: application/xml", "Content-Type: application/xml", "authorization: apikey "..AlmaApiInternal.ApiKey};
    local requestUrl = AlmaApiInternal.ApiUrl .. "bibs/"..mms_id.."/requests?user_id_type=all_unique&allow_same_request=true&user_id="..Utility.URLEncode(user)
    log:DebugFormat("Request URL: {0}", requestUrl)
    local body = [[
<user_request>
    <request_type>HOLD</request_type>
    <pickup_location_type>]]..pickup_location_type..[[</pickup_location_type>
    <pickup_location_library>]] .. pickup_location ..[[</pickup_location_library>
    <pickup_location_circulation_desk>DEFAULT_CIRC_DESK</pickup_location_circulation_desk>
</user_request>]]
    log:DebugFormat("request body: {0}", body);
    local success, response = pcall(WebClient.PostRequest, requestUrl, headers, body)
    log:DebugFormat("response = {0}", response)
    log:DebugFormat("success: {0}", success)
    if success then
        -- we expect to get an xml document as the response object in a successful hold attempt
        log:Debug("call to webClient.post request was successful")
        interfaceMngr:ShowMessage("Hold placed for user: ".. WebClient.ReadResponse(response):GetElementsByTagName("user_primary_id"):Item(0).InnerText, "Place LSA Hold");
        return
    else
        -- If the hold attempt fails, we expect the error object to contain a string of xml from the Alma server.
        -- Convert that string to an xml document and throw an error.
        -- show an error message and throw an error
        local error_message = WebClient.ReadResponse(response):GetElementsByTagName("errorMessage"):Item(0).InnerText
        interfaceMngr:ShowMessage("Hold failed: ".. error_message, "ERROR")
        error(error_message)
    end
end

-- Exports
AlmaApi.RetrieveHoldingsList = RetrieveHoldingsList
AlmaApi.RetrieveBibs = RetrieveBibs
AlmaApi.RetrieveItemByBarcode = RetrieveItemByBarcode
AlmaApi.PlaceHoldByItemPID = PlaceHoldByItemPID
AlmaApi.PlaceHoldByMmsId = PlaceHoldByMmsId