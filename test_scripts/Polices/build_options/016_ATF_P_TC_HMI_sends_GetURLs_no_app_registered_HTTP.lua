-- UNREADY: 
-- Please note still not implemented functions: 
-- testCasesForPolicyTable:flow_PTU_SUCCEESS_HTTP() and testCasesForPolicyTable:trigger_PTU_user_press_button_HMI

---------------------------------------------------------------------------------------------
-- Requirements summary:
-- In case HMI sends GetURLs and no apps registered SDL must return only default url
-- [HMI API] GetURLs request/response
--
-- Description:
-- SDL should request PTU in case user requests PTU
-- 1. Used preconditions
-- SDL is built with "-DEXTENDED_POLICY: HTTP" flag
-- Application is registered. AppID is listed in PTS
-- No PTU is requested.
-- 2. Performed steps
-- Unregister application.
-- User press button on HMI to request PTU.
-- HMI->SDL: SDL.GetURLs(service=0x07)
--
-- Expected result:
-- PTU is requested. PTS is created.
-- SDL.GetURLs({urls[] = default})
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')
local testCasesForPolicyTableSnapshot = require('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--TODO(mmihaylova-banska): Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Preconditions ]]
--TODO(mmihaylova-banska): Function still not implemented
function Test.Precondition_PTU_flow_SUCCESS ()
  testCasesForPolicyTable:flow_PTU_SUCCEESS_HTTP()
  print(" \27[31m Function flow_PTU_SUCCEESS_HTTP is not yet implemented! \27[0m")
end

function Test:Precondition_UnregisterApp()
  local CorIdURAI = self.mobileSession:SendRPC("UnregisterAppInterface", {})
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered",
    {appID = self.applications[config.application1.registerAppInterfaceParams.appName], unexpectedDisconnect = false})
  EXPECT_RESPONSE("UnregisterAppInterface", {success = true , resultCode = "SUCCESS"})
end

-- Request PTU
--TODO(mmihaylova-banska): Function still not implemented
testCasesForPolicyTable:trigger_PTU_user_press_button_HMI()

--[[ Test ]]
--TODO(mmihaylova-banska): Function still not implemented
function Test:TestStep_PTU_GetURLs_NoAppRegistered()
  local endpoints = {}
  local is_app_esxist = false

  for i = 1, #testCasesForPolicyTableSnapshot.pts_endpoints do
    if (testCasesForPolicyTableSnapshot.pts_endpoints[i].service == "0x07") then
      endpoints[#endpoints + 1] = { url = testCasesForPolicyTableSnapshot.pts_endpoints[i].value, appID = nil}
    end

    if (testCasesForPolicyTableSnapshot.pts_endpoints[i].service == "app1") then
      -- app id should be included in PTS but not to be used
      is_app_esxist = true
    end
  end

  local RequestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })

  EXPECT_HMIRESPONSE(RequestId,{result = {code = 0, method = "SDL.GetURLS", urls = endpoints} } )
  :Do(function(_,data)
      if(is_app_esxist == false) then
        self:FailTestCase("endpoints for application doesn't exist!")
      end
    end)
end

return Test
