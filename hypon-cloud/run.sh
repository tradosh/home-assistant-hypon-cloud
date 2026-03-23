#!/usr/bin/with-contenv bashio

source scripts/home-assistant.sh
source scripts/hypon.sh
source scripts/mqtt.sh
source scripts/variables.sh

loadSensorData() {
  authToken=$1

  while true
  do
  	solarData=$(retrieveSolarData "$authToken")
  	realTimeData=$(retrieveRealTimeSolarData "$authToken")

  	solarDataResponseCode=$(echo $solarData | jq -r '.code')

    bashio::log.debug "Response Code From loading solar data: $solarDataResponseCode"

    if [ "$solarDataResponseCode" = "20000" ]; then
      bashio::log.debug "Data retrieved successfully: $solarData"

      bashio::log.info "Updating Daily Sensors"
      update-sensor "$SOLAR_PRODUCTION_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.kwhac')" $SOLAR_PRODUCTION_SENSOR_NAME
      update-sensor "$GRID_IMPORT_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.load_from_grid')" $GRID_IMPORT_SENSOR_NAME
      update-sensor "$GRID_EXPORT_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.pv_to_grid')" $GRID_EXPORT_SENSOR_NAME
      update-sensor "$ENERGY_CONSUMPTION_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.load')" $ENERGY_CONSUMPTION_TODAY_SENSOR_NAME
      update-sensor "$SOLAR_USED_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.load_from_pv')" $SOLAR_USED_TODAY_SENSOR_NAME
      update-sensor "$BATTERY_USED_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.load_from_bat')" $BATTERY_USED_TODAY_SENSOR_NAME
      update-sensor "$SOLAR_CHARGE_USED_TODAY_TEMPLATE" "$(echo "$solarData" | jq -r '.data.pv_to_bat')" $SOLAR_CHARGE_USED_TODAY_SENSOR_NAME

      bashio::log.info "Updating Real Time Sensors"
      update-sensor "$SOLAR_PRODUCTION_REAL_TIME_TEMPLATE" "$(echo "$realTimeData" | jq -r '.data.power_pv')" $SOLAR_PRODUCTION_REAL_TIME_NAME
      update-sensor "$GRID_IMPORT_REAL_TIME_TEMPLATE" "$(echo "$realTimeData" | jq -r '.data.meter_power')" $GRID_IMPORT_REAL_TIME_NAME
      update-sensor "$POWER_LOAD_REAL_TIME_TEMPLATE" "$(echo "$realTimeData" | jq -r '.data.power_load')" $POWER_LOAD_REAL_TIME_NAME
      update-sensor "$BATTERY_USE_REAL_TIME_TEMPLATE" "$(echo "$realTimeData" | jq -r '.data.power_bat // .data.w_cha // .data.power_load')" $BATTERY_USE_REAL_TIME_NAME
      update-sensor "$BATTERY_SOC_REAL_TIME_TEMPLATE" "$(echo "$realTimeData" | jq -r '.data.soc // "unknown"')" $BATTERY_SOC_REAL_TIME_NAME

    else
      bashio::log.error "Data Retrieval Error - updating auth token"
      authToken=$(loginHypon)
    fi
  	sleep "$(bashio::config 'refresh_time')"
  done
}

bashio::log.info "Loading Authentication Token"
authToken=$(loginHypon)
startMqttControlLoop &
loadSensorData "$authToken"
