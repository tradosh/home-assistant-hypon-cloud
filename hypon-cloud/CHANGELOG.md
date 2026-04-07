# Changelog

## 1.3.5
- Added bounded exponential backoff for Hypon API login/daily/realtime requests (4 attempts, 1s initial delay, 8s max)
- Hardened API response parsing to verify JSON before running `jq` and avoid intermittent parse failures
- Improved error handling to refresh auth and continue when Hypon endpoints return transient non-JSON payloads

## 1.3.4
- Changed default MQTT inverter sync interval to `7200` seconds (120 minutes)
- Added MQTT `0 Sync Status` sensor updates during periodic `TimeMode1..4` polling
- Fixed slot action state so `Enable Disable Slot` reflects the selected slot's actual `time_enable` status
- Added per-slot MQTT binary sensors: `Slot 1 Enabled` to `Slot 4 Enabled`

## 1.3.3
- Added periodic inverter slot sync from `/inverter/<inverter_sn>/config/TimeMode1..4` into MQTT state/entities
- Added MQTT sync options: `mqtt_sync_from_hypon` and `mqtt_sync_interval`
- Added apply progress/status feedback and response confirmation wait using `/inverter/<inverter_sn>/response`

## 1.3.2
 - Update the MQTT controls to represent better the UI of the HyponCloud app/UI

## 1.3.1
- Removed slot/time-mode schedule fields from add-on options; schedule configuration is now MQTT-device driven only
- Removed startup apply path based on add-on slot settings to avoid split configuration sources
- Updated documentation with MQTT-first setup steps and clearer control descriptions

## 1.3.0
- Added MQTT discovery-based TimeMode controls so settings can be managed as Home Assistant device entities
- Added MQTT command listener to apply `TimeMode` and `disableTimeMode` payloads from HA UI controls
- Added add-on options for MQTT broker/discovery configuration and apply-on-change behavior
- Updated MQTT controls so each slot (1-4) keeps independent mode/power/start/end values and improved entity naming/description clarity

## 1.2.0
- Added optional inverter `TimeMode` API write support for battery charge/discharge schedule and power
- Added add-on configuration options for `timemode`, `timepower`, schedule window, weekdays, inverter serial, and configurable config write endpoint/method
- Updated default config write route to `/inverter/config` with `PUT` based on observed Hypon web app API request
- Fixed startup jq parse crash when TimeMode numeric options are missing/invalid by coercing values safely
- Added `time_mode_action` with `disable` support to send `configname: disableTimeMode` for a selected schedule slot (`timen` 1-4)

## 1.1.3
- Added `sensor.battery_charge_now` realtime mapping from the Hypon monitor API battery state-of-charge field (`soc`)

## 1.1.2
- Fixed `sensor.battery_power_flow_now` realtime mapping to use battery flow fields from the Hypon monitor API (`power_bat` with `w_cha` fallback)

## 1.1.1
- Updating login process to include oem field based on hyponcloud changes
- 
## 1.1.0
- Adding User Agent String
- 
## 1.0.9
- Added Change log
- Refactored variables to a separate file for readability 
- Changing real time data to be tracked as watts

## 1.0.8

- Added real time data values for solar being generated and power consumed from the grid as well as export to grid.

## 1.0.7

- Initial Release of the Hypon plugin with daily sensor data