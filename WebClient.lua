WebClient = {};

local types = {};
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager");
types["System.Net.WebClient"] = luanet.import_type("System.Net.WebClient");
types["System.Text.Encoding"] = luanet.import_type("System.Text.Encoding");
types["System.Xml.XmlTextReader"] = luanet.import_type("System.Xml.XmlTextReader");
types["System.Xml.XmlDocument"] = luanet.import_type("System.Xml.XmlDocument");
types["System.IO.StreamReader"] = luanet.import_type("System.IO.StreamReader")

-- Create a logger
local log = types["log4net.LogManager"].GetLogger(rootLogger .. ".WebClient");

local function GetRequest(requestUrl, headers)
    local webClient = types["System.Net.WebClient"]();
    log:Debug("Created Web Client");
    webClient.Encoding = types["System.Text.Encoding"].UTF8;

    for _, header in ipairs(headers) do
        webClient.Headers:Add(header);
    end

    local success, response = pcall(webClient.DownloadString, webClient, requestUrl);
    log:Debug("GET request sent");
    webClient:Dispose();
    log:Debug("Disposed Web Client");

    if(success) then
        -- return the body of the response as a string
        return response;
    else
        -- if webclient.DownloadString throws a WebException
        -- then throw an error containing the response body
        -- as a string
        local serverResponse = response.InnerException.Response;
        local dataRs = serverResponse:GetResponseStream();
        local reader = types["System.IO.StreamReader"](dataRs);
        local responseBody = reader:ReadToEnd();

        log:Error(responseBody);
        log:Error(response.InnerException.Status);
        log:Error(response.InnerException.Message);
        log:Error("POST request unsuccessful");
        log:Error(response:GetBaseException());
        error(responseBody,0);
    end
end

local function PostRequest(requestUrl, headers, body)
    local webClient = types["System.Net.WebClient"]();
    log:Debug("Created Web Client");
    webClient.Encoding = types["System.Text.Encoding"].UTF8;

    for _, header in ipairs(headers) do
        webClient.Headers:Add(header);
    end

    local success, response = pcall(webClient.UploadString, webClient, requestUrl, body);
    log:Debug("POST request sent");
    webClient:Dispose();
    log:Debug("Disposed Web Client");

    if success then
        -- return the body of the response as a string
        return response;
    else
        -- if webclient.UploadString throws a WebException
        -- then throw an error containing the response body
        -- as a string
        local serverResponse = response.InnerException.Response;
        local dataRs = serverResponse:GetResponseStream();
        local reader = types["System.IO.StreamReader"](dataRs);
        local responseBody = reader:ReadToEnd();

        log:Error(responseBody);
        log:Error(response.InnerException.Status);
        log:Error(response.InnerException.Message);
        log:Error("POST request unsuccessful");
        log:Error(response:GetBaseException());
        error(responseBody,0);
    end
end
local function ReadResponse( responseString )
    if (responseString and #responseString > 0) then

        local responseDocument = types["System.Xml.XmlDocument"]();

        local documentLoaded, error = pcall(function ()
            responseDocument:LoadXml(responseString);
        end);

        if (documentLoaded) then
            return responseDocument;
        else
            log:ErrorFormat("Unable to load response content as XML: {0}", error);
            return nil;
        end
    else
        log:Error("Unable to read response content");
    end

    return nil;
end


--Exports
WebClient.GetRequest = GetRequest;
WebClient.PostRequest = PostRequest;
WebClient.ReadResponse = ReadResponse;