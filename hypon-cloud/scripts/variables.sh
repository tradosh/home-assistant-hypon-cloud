#Names for Daily Sensors
declare SOLAR_PRODUCTION_SENSOR_NAME="sensor.solar_generated_today"
declare GRID_IMPORT_SENSOR_NAME="sensor.grid_import_today"
declare GRID_EXPORT_SENSOR_NAME="sensor.grid_export_amount"
declare ENERGY_CONSUMPTION_TODAY_SENSOR_NAME="sensor.energy_consumption_today"
declare SOLAR_USED_TODAY_SENSOR_NAME="sensor.solar_used_today"
declare BATTERY_USED_TODAY_SENSOR_NAME="sensor.battery_used_today"
declare SOLAR_CHARGE_USED_TODAY_SENSOR_NAME="sensor.solar_battery_charge_today"

#Names for Real Time Sensors
declare SOLAR_PRODUCTION_REAL_TIME_NAME="sensor.solar_energy_now"
declare GRID_IMPORT_REAL_TIME_NAME="sensor.grid_import_now"
declare POWER_LOAD_REAL_TIME_NAME="sensor.power_load_now"
declare BATTERY_USE_REAL_TIME_NAME="sensor.battery_power_flow_now"

#Template Values for Daily Sensors
declare SOLAR_PRODUCTION_TODAY_TEMPLATE='{"state": "unknown", "attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Solar generated today"}}'
declare GRID_IMPORT_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Grid Import today"}}'
declare GRID_EXPORT_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Grid Export Amount"}}'
declare ENERGY_CONSUMPTION_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Energy Consumption today"}}'
declare SOLAR_USED_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Solar Used Today"}}'
declare BATTERY_USED_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Battery Used Today"}}'
declare SOLAR_CHARGE_USED_TODAY_TEMPLATE='{"state": "unknown","attributes": {"state_class": "total_increasing","unit_of_measurement": "kWh","device_class": "energy","friendly_name": "Solar to Battery Used Today"}}'

#Template Values for Real Time Sensors
declare SOLAR_PRODUCTION_REAL_TIME_TEMPLATE='{"state": "unknown","attributes": {"state_class": "measurement","unit_of_measurement": "W","device_class": "energy","friendly_name": "Solar Energy Realtime"}}'
declare GRID_IMPORT_REAL_TIME_TEMPLATE='{"state": "unknown","attributes": {"state_class": "measurement","unit_of_measurement": "W","device_class": "energy","friendly_name": "Grid Used Now"}}'
declare POWER_LOAD_REAL_TIME_TEMPLATE='{"state": "unknown","attributes": {"state_class": "measurement","unit_of_measurement": "W","device_class": "energy","friendly_name": "House Consumption Now"}}'
declare BATTERY_USE_REAL_TIME_TEMPLATE='{"state": "unknown","attributes": {"state_class": "measurement","unit_of_measurement": "W","device_class": "energy","friendly_name": "Battery Power Flow Now"}}'
