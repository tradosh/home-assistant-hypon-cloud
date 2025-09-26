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
    local loginResponse

    username=$(bashio::config 'username')
    password=$(bashio::config 'password')

    bashio::log.info "Login Start"

    loginResponse=$(curl -s "$HYPON_URL/login" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "User-Agent: Mozilla/5.0" \
      --data-urlencode "username=$username" \
      --data-urlencode "password=$password" \
      --data-urlencode "oem=")

    bashio::log.info "Login End"
    echo "$loginResponse" | jq -r '.data.token'
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
