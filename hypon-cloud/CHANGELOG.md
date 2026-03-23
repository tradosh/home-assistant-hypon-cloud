# Changelog

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