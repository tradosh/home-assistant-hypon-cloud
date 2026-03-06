# Changelog

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