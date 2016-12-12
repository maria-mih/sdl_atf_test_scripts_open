---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [PolicyTableUpdate] Local Policy Table retry sequence start
--
-- Description:
--      In case PoliciesManager does not receive the Updated PT during time defined in
--      "timeout_after_x_seconds" section of Local PT, it must start the retry sequence.
-- 1. Used preconditions
--      SDL is built with "-DEXTENDED_POLICY: PROPRIETARY" flag
--      Application not in PT is registered -> PTU is triggered
--      SDL->HMI: SDL.OnStatusUpdate(UPDATE_NEEDED)
--      SDL->HMI:SDL.PolicyUpdate(file, timeout, retry[])
--      HMI -> SDL: SDL.GetURLs (<service>)
--      HMI->SDL: BasicCommunication.OnSystemRequest ('url', requestType: PROPRIETARY)
-- 2. Performed steps
--      SDL->app: OnSystemRequest ('url', requestType:PROPRIETARY, fileType="JSON")
-- Expected result:
--      Timeout expires and retry sequence started
--      SDL->HMI: SDL.OnStatusUpdate(UPDATE_NEEDED)
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
--[TODO: shall be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local commonPreconditions = require ('user_modules/shared_testcases/commonPreconditions')
local testCasesForPolicyTableSnapshot = require ('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()
commonPreconditions:Connecttest_without_ExitBySDLDisconnect_WithoutOpenConnectionRegisterApp("connecttest_RAI.lua")

--[[ General Settings for configuration ]]
Test = require('user_modules/connecttest_RAI')
require('cardinalities')
require('user_modules/AppTypes')
local mobile_session = require('mobile_session')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")
function Test:Precondition_Connect_mobile()
  self:connectMobile()
end

function Test:Precondition_Start_new_session()
  self.mobileSession = mobile_session.MobileSession( self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
function Test:Start_Retry_Sequence_PROPRIETARY()
  local correlationId = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.appName } })
    :Do(function(_,data)
    local hmi_app_id = data.params.application.appID
    EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATE_NEEDED"})

    testCasesForPolicyTableSnapshot:create_PTS(true,
    {config.application1.registerAppInterfaceParams.appID},
    {config.deviceMAC},
    {hmi_app_id})

    local timeout_after_x_seconds = testCasesForPolicyTableSnapshot:get_data_from_PTS("module_config.timeout_after_x_seconds")
    local seconds_between_retries = {}
    for i = 1, #testCasesForPolicyTableSnapshot.pts_seconds_between_retries do
      seconds_between_retries[i] = testCasesForPolicyTableSnapshot.pts_seconds_between_retries[i].value
    end
    EXPECT_HMICALL("BasicCommunication.PolicyUpdate",
    {
      file = "/tmp/fs/mp/images/ivsu_cache/PolicyTableUpdate",
      timeout = timeout_after_x_seconds,
      retry = seconds_between_retries
    })
    :Do(function(_,_)
      EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATING"})
      :Times(1)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
        :Do(function(_,_)
        local ptu_file_path = "files/"
        local ptu_file_name = "PolicyTableUpdate"
        local ptu_file = "ptu.json"
        local SystemFilesPath = "/tmp/fs/mp/images/ivsu_cache/"
        local RequestId_GetUrls = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
        EXPECT_HMIRESPONSE(RequestId_GetUrls,{result = {code = 0, method = "SDL.GetURLS", urls = {{url = "http://policies.telematics.ford.com/api/policies"}}}})
          :Do(function(_,_)
          self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",{ requestType = "PROPRIETARY", fileName = "PolicyTableUpdate"})
          EXPECT_NOTIFICATION("OnSystemRequest", {requestType = "PROPRIETARY"})
            :Do(function(_,_)
            local CorIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", {requestType = "PROPRIETARY", fileName = "PolicyTableUpdate", hmi_app_id, ptu_file_path..ptu_file})
            EXPECT_HMICALL("BasicCommunication.SystemRequest",{ requestType = "PROPRIETARY", fileName = SystemFilesPath..ptu_file_name })
              :Do(function(_,_data1)
              self.hmiConnection:SendResponse(_data1.id,"BasicCommunication.SystemRequest", "SUCCESS", {})
              end)
            EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATE_NEEDED"})
            :Times(1)
            end)
          end)
        end)
      end)
    end)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test:Postcondition_Force_Stop_SDL()
  commonFunctions:SDLForceStop(self)
end
