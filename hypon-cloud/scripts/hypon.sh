#!/usr/bin/with-contenv bashio

declare LOGIN_TEMPLATE='{"username":"","password":"","oem":null}'
declare HYPON_URL="https://api.hypon.cloud/v2"
declare ACCEPT_HEADER="accept: application/json"
declare CONTENT_HEADER="content-type: application/json;charset=UTF-8"

# ------------------------------------------------------------------------------
# Authenticate with the Hypon Cloud Platform
#
# Arguments
#  $1 The template value for the sensor
#  $2 The value to use for the sensor
#  $3 The name of the sensor
# ------------------------------------------------------------------------------
loginHypon () {
    local username
    local password
    local loginData

    local loginResponse

    username=$(bashio::config 'username')
    password=$(bashio::config 'password')
    loginData=$(echo "$LOGIN_TEMPLATE" | jq .username="\"$username\"" | jq .password="\"$password\"" | jq .oem=null)

    bashio::log.info "Login Start"

    loginResponse=$(curl -s "$HYPON_URL/login" \
      -H "$ACCEPT_HEADER" \
      -H "$CONTENT_HEADER" \
      -H 'User-Agent: Mozilla/5.0' \
      --data-raw "$loginData")

      bashio::log.info "Login End"
      echo $loginResponse | jq -r '.data.token'
}

# ------------------------------------------------------------------------------
# Retrieve solar data from the Hypon Cloud Platform
#
# Arguments
#  $1 The authentication token to use
# ------------------------------------------------------------------------------
retrieveSolarData () {
  local authToken=${1}
  local system_id
  local dataUrl
  local dataRequest

    system_id=$(bashio::config 'system_id')
    dataUrl="$HYPON_URL/plant/$system_id/energy2?day=$(date +%d)&month=$(date +%m)&type=day&year=$(date +%Y)"

        bashio::log.info "Load Solar Data Start"

    dataRequest=$(curl -s "$dataUrl" \
                              -H "$ACCEPT_HEADER" \
                              -H 'User-Agent: Mozilla/5.0' \
                              -H "authorization: Bearer $authToken")

        bashio::log.info "Load Solar Data End"
    echo $dataRequest
}

# ------------------------------------------------------------------------------
# Retrieve real time solar data from the Hypon Cloud Platform
#
# Arguments
#  $1 The authentication token to use
# ------------------------------------------------------------------------------
retrieveRealTimeSolarData () {
  local authToken=${1}
  local system_id
  local dataUrl
  local dataRequest

    bashio::log.info "Load Realtime Start"

    system_id=$(bashio::config 'system_id')
    dataUrl="$HYPON_URL/plant/$system_id/monitor?refresh=true"
    dataRequest=$(curl -s "$dataUrl" \
                              -H "$ACCEPT_HEADER" \
                              -H 'User-Agent: Mozilla/5.0' \
                              -H "authorization: Bearer $authToken")

    bashio::log.info "Load Realtime Data End"
    echo $dataRequest
}

# ------------------------------------------------------------------------------
# Apply inverter TimeMode settings via the Hypon config endpoint.
#
# Arguments
#  $1 The authentication token to use
# ------------------------------------------------------------------------------
applyTimeModeConfig () {
  local authToken=${1}
  local enableConfig
  local inverterSn
  local configEndpoint
  local configMethod
  local timeModeAction
  local timeSlot
  local payload
  local response
  local responseCode
  local responseMessage

  enableConfig=$(bashio::config 'enable_time_mode_config')
  if [ "$enableConfig" != "true" ]; then
    return 0
  fi

  inverterSn=$(bashio::config 'inverter_sn')
  if [ -z "$inverterSn" ]; then
    bashio::log.error "TimeMode config enabled but inverter_sn is empty"
    return 1
  fi

  configEndpoint=$(bashio::config 'config_put_endpoint')
  if [ -z "$configEndpoint" ] || [ "$configEndpoint" = "null" ]; then
    configEndpoint="/inverter/config"
  fi

  if [[ "$configEndpoint" != /* ]]; then
    configEndpoint="/$configEndpoint"
  fi

  configMethod=$(bashio::config 'config_put_method')
  if [ -z "$configMethod" ] || [ "$configMethod" = "null" ]; then
    configMethod="PUT"
  fi
  configMethod=$(echo "$configMethod" | tr '[:lower:]' '[:upper:]')

  timeModeAction=$(bashio::config 'time_mode_action')
  if [ -z "$timeModeAction" ] || [ "$timeModeAction" = "null" ]; then
    timeModeAction="set"
  fi
  timeModeAction=$(echo "$timeModeAction" | tr '[:upper:]' '[:lower:]')

  timeSlot=$(echo "$(bashio::config 'timen')" | jq -Rr 'try (tonumber) catch 1 | if . < 1 then 1 elif . > 4 then 4 else . end')

  if [ "$timeModeAction" = "disable" ]; then
    payload=$(jq -n \
      --arg invsn "$inverterSn" \
      --arg configname "disableTimeMode" \
      --argjson timen "$timeSlot" \
      '{
        invsn: $invsn,
        configname: $configname,
        timen: $timen
      }')
    bashio::log.info "Disabling inverter TimeMode schedule slot $timeSlot"
  else
    payload=$(jq -n \
      --arg invsn "$inverterSn" \
      --arg configname "TimeMode" \
      --arg timestarttime "$(bashio::config 'timestarttime')" \
      --arg timeendtime "$(bashio::config 'timeendtime')" \
      --arg old_time_enable "$(bashio::config 'old_time_enable')" \
      --arg time_enable "$(bashio::config 'time_enable')" \
      --arg timemode "$(bashio::config 'timemode')" \
      --argjson timen "$timeSlot" \
      --arg timepower "$(bashio::config 'timepower')" \
      --arg timeweekday1 "$(bashio::config 'timeweekday1')" \
      --arg timeweekday2 "$(bashio::config 'timeweekday2')" \
      --arg timeweekday3 "$(bashio::config 'timeweekday3')" \
      --arg timeweekday4 "$(bashio::config 'timeweekday4')" \
      --arg timeweekday5 "$(bashio::config 'timeweekday5')" \
      --arg timeweekday6 "$(bashio::config 'timeweekday6')" \
      --arg timeweekday7 "$(bashio::config 'timeweekday7')" \
      '{
        invsn: $invsn,
        configname: $configname,
        timestarttime: $timestarttime,
        timeendtime: $timeendtime,
        old_time_enable: $old_time_enable,
        time_enable: $time_enable,
        timemode: (try ($timemode | tonumber) catch 0),
        timen: $timen,
        timepower: (try ($timepower | tonumber) catch 100),
        timeweekday1: (try ($timeweekday1 | tonumber) catch 1),
        timeweekday2: (try ($timeweekday2 | tonumber) catch 1),
        timeweekday3: (try ($timeweekday3 | tonumber) catch 1),
        timeweekday4: (try ($timeweekday4 | tonumber) catch 1),
        timeweekday5: (try ($timeweekday5 | tonumber) catch 1),
        timeweekday6: (try ($timeweekday6 | tonumber) catch 1),
        timeweekday7: (try ($timeweekday7 | tonumber) catch 1)
      }')
    bashio::log.info "Applying inverter TimeMode settings"
  fi

  response=$(curl -s "$HYPON_URL$configEndpoint" \
    -X "$configMethod" \
    -H "$ACCEPT_HEADER" \
    -H "$CONTENT_HEADER" \
    -H 'User-Agent: Mozilla/5.0' \
    -H "authorization: Bearer $authToken" \
    --data-raw "$payload")

  if echo "$response" | jq -e . >/dev/null 2>&1; then
    responseCode=$(echo "$response" | jq -r '.code // "unknown"')
    responseMessage=$(echo "$response" | jq -r '.message // "unknown"')
  else
    responseCode="non_json"
    responseMessage="Non-JSON response from Hypon API"
  fi

  if [ "$responseCode" = "20000" ]; then
    bashio::log.info "TimeMode settings applied successfully"
    return 0
  fi

  bashio::log.error "Failed to apply TimeMode settings. method=$configMethod endpoint=$configEndpoint code=$responseCode message=$responseMessage"
  bashio::log.debug "TimeMode config response: $response"
  return 1
}
