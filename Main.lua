require "Atlas.AtlasHelpers";
local rootLogger = "AtlasSystems.Addons.AlmaBarcodeLookupAddon";

luanet.load_assembly("System.Windows.Forms");  -- For cursor manipulation
luanet.load_assembly("log4net");
luanet.load_assembly("System.Xml");

-- Load the .Net types that we will be using.
local types = {};
types["System.Windows.Forms.Cursor"] = luanet.import_type("System.Windows.Forms.Cursor");
types["System.Windows.Forms.Cursors"] = luanet.import_type("System.Windows.Forms.Cursors");
types["System.Windows.Forms.Application"] = luanet.import_type("System.Windows.Forms.Application");
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager");
local log = types["log4net.LogManager"].GetLogger(rootLogger);
log:Debug("Finished creating types");

-- Load settings
local settings = {};
settings.LookupType = GetSetting("Look Up Type");
settings.AlmaApiUrl = GetSetting("Alma API URL");
settings.AlmaApiKey = GetSetting("Alma API Key");
settings.AllowOverwriteWithBlankValue = GetSetting("Allow Overwrite With Blank Value");
settings.FieldsToImport = Utility.StringSplit(",", GetSetting("Fields to Import"));
settings.FieldToPerformLookupWith = GetSetting("Field to Perform Lookup With");
settings.UserForLSAHoldRequest = GetSetting("User For LSA Hold Request");
settings.pickup_location = GetSetting("location code for LSA hold shelf");

-- We will store the interface manager object here so that we don't have to make multiple GetInterfaceManager calls.
local interfaceMngr = nil;
log:Debug("Created Interface Manager");

local product = types["System.Windows.Forms.Application"].ProductName;

function Init()
  log:Debug("Starting");
  interfaceMngr = GetInterfaceManager();
  log:Debug("Got Interface Manager");

  -- Retrieve Ribbon Page and Add Buttons.
  local ribbonPage = interfaceMngr:CreateRibbonPage("Barcode Lookup");
  log:Debug("Created Ribbon Page");

  ribbonPage:CreateButton("Import by Barcode", GetClientImage(DataMapping.ClientImage[product]), "ImportItem", "Options");
  ribbonPage:CreateButton("Place LSA Hold", GetClientImage(DataMapping.ClientImage[product]), "PlaceLSAHold", "Options");

  log:Debug("Created Buttons");

  -- Find the field to perform lookup with
  if settings.FieldToPerformLookupWith:lower() == "{default}" then
    settings.FieldToPerformLookupWith = Utility.StringSplit(".", DataMapping.BarcodeFieldMapping[product]);
    settings.FieldToPerformLookupWith[1] = Utility.Trim(settings.FieldToPerformLookupWith[1]);
    settings.FieldToPerformLookupWith[2] = Utility.Trim(settings.FieldToPerformLookupWith[2]);
    log:InfoFormat("Field to Perform Lookup With is {0}.{1}", settings.FieldToPerformLookupWith[1], settings.FieldToPerformLookupWith[2]);
  else
    log:Warn("Invalid Field to Perform Lookup With");
  end

  InitializeVariables();

end

function InitializeVariables()
  log:Debug("Initializing Variables");
  AlmaLookup.InitializeVariables(settings.AlmaApiUrl, settings.AlmaApiKey, settings.AllowOverwriteWithBlankValue, settings.FieldsToImport);
  log:Debug("Finished Initializing Variables");
end

function ImportItem()
  log:Debug("Importing Item...");
  local lookupResult = DoLookup();
  log:Debug("DoLookup Complete");

  if(lookupResult ~= nil) then
    for _, result in ipairs(lookupResult) do
      log:InfoFormat("Importing {0} into {1}.{2}", result.valueToImport, result.valueDestination[1], result.valueDestination[2]);
      SetFieldValue(result.valueDestination[1], result.valueDestination[2], result.valueToImport);
    end
  else
    interfaceMngr:ShowMessage("No item found.", "Item Not found");
  end
end

-- Returns a lookUpResult that contains a valueDestination array and the value to import
-- The valueDestination array has the table in the first position and the column in the second
function DoLookup()
  -- Set the mouse cursor to busy.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].WaitCursor;
  local itemBarcode = GetBarcode();
  local lookupResult = AlmaLookup.DoLookup(itemBarcode);

  -- Set the mouse cursor back to default.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].Default;

  return lookupResult;
end

function GetBarcode()
  
  local itemBarcode = nil;
  local succeeded, result = pcall(function() return GetFieldValue(settings.FieldToPerformLookupWith[1], settings.FieldToPerformLookupWith[2]) end)
  if succeeded then
    itemBarcode = result;
  end

  if itemBarcode == nil  or itemBarcode == "" then
    log:Warn("Barcode is nil");
    interfaceMngr:ShowMessage("Barcode is nil");
  end
  
  return itemBarcode;
end

function GetItemPID(barcode)
  log:InfoFormat("getting item ID for barcode: {0}", barcode);
  local succeeded, response = pcall(AlmaApi.RetrieveItemByBarcode, barcode);
  if succeeded then
    --get Item PID from XML response
    local item_id = response:GetElementsByTagName("pid"):Item(0).InnerText;
    log:InfoFormat("item_id: {0}", item_id);
    return item_id
  else
      log:Error("Error Getting item PID");
  end

end

function PlaceLSAHold()

-- Places a hold on behalf of the user defined in config.xml to be held for pickup at the circ desk defined in config.xml.

-- Set the mouse cursor to busy.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].WaitCursor;

  -- get the barcode from the illiad record
  local itemBarcode = GetBarcode();

  -- use the barcode to get the PID from Alma
  local item_id = GetItemPID(itemBarcode);

  --Place hold in Alma using using PID
  local holdResponse = AlmaApi.PlaceHoldByItemPID(item_id,
      settings.UserForLSAHoldRequest, settings.pickup_location);
  log:DebugFormat("placing hold with item_id: {0}, user: {1}, pickup location: {2}", item_id, settings.UserForLSAHoldRequest, settings.pickup_location);
  -- when a hold is successfully placed, the result will have an xml document with a root 
  -- element of "user_request". An unsuccessful hold will have an empty holdresponse.
  -- it doesn't seem like the luanet module that lua is using to integration with .net is -- able to return the webexception error thrown by System.Net.WebClient when a hold 
  -- request is rejected by the Alma API. 
  -- see https://code.google.com/archive/p/luainterface/issues/59
  if(holdResponse ~= nil) and holdResponse.DocumentElement.Name == "user_request" then
    interfaceMngr:ShowMessage("Hold placed successfully.", "Place LSA Hold");
    log:Info(holdResponse.DocumentElement.Name);
    log:DebugFormat("holdResponse: {0}", holdResponse);
  else
    interfaceMngr:ShowMessage("Hold failed", "Place LSA Hold");
    log:Error("error: holdResponse is nil");
  end

  -- Set the mouse cursor back to default.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].Default;

end
