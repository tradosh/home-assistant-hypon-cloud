# Hypon Cloud Addon for Home Assistant

This repository contains a Hypon cloud integration for Home Assistant.  This is provided without warranty and is for personal use only.

## Installation

### Method 1: Add-on Repository

1.	In Home Assistant go to: Settings → Add-ons → Add-on store → ⋮ → Repositories
2.	Paste this URL:
```https://github.com/amckee23/home-assistant-hypon-cloud```
3. Find **Hypon Cloud** under “Hypon Cloud Addon for Home Assistant” and click **Install**.

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Famckee23%2Fhome-assistant-hypon-cloud)

### Method 2: Manual Installation

1. Clone this repository to your local machine:
git clone https://github.com/amckee23/home-assistant-hypon-cloud hypon_cloud
cd into the hypon_cloud folder

2. from the top level of the repository run `scp -r -O hypon-cloud [user]@[ip]:/addons`
    Note:: Please ensure you have the ssh plugin installed in home assistant with sftp enabled.  Instructions can be found [here](https://community.home-assistant.io/t/home-assistant-community-add-on-ssh-web-terminal/33820)

3. Navigate in your Home Assistant frontend to **Settings** -> **Add-ons** -> **Add-on Store** -> **Select 3 button menu** -> **Check for updates** 

4. Install the Hypon Cloud Addon. Ensuring the following configuration is set:
    - `username` - Your Hypon Cloud username
    - `password` - Your Hypon Cloud password
    - `system_id` - The system ID of the Hypon device you wish to control (this can be found in the Hypon Cloud dashboard)
    - `refresh_time` - The time in seconds between each refresh of the Hypon Cloud Data

## Sensors 
The following sensors are available once the addon is installed:

### Daily Sensors
- `sensor.solar_generated_today` - The amount of solar energy generated today
- `sensor.grid_import_today` - The amount of energy imported from the grid today
- `sensor.grid_export_amount` - The amount of energy exported to the grid today
- `sensor.energy_consumption_today` - The total energy consumption today
- `sensor.solar_used_today` - The total amount of solar energy used today

### Real Time Sensors
- `sensor.solar_energy_now` - The amount of solar energy generated in real time
- `sensor.grid_import_now` - The amount of energy imported from the grid in real time
- `sensor.power_load_now` - House consumption in real time from Hypon monitor data (`power_load`)
- `sensor.battery_power_flow_now` - Battery power flow in real time from Hypon monitor data (`power_bat` or `w_cha`)
- `sensor.battery_charge_now` - Battery state of charge in real time from Hypon monitor data (`soc`)

## MQTT Device Controls (Option 2)

This add-on exposes TimeMode controls as MQTT discovery entities so you configure schedules from Home Assistant devices/entities (not add-on options).
Each slot (`1` to `4`) stores its own independent `mode`, `power`, `start`, and `end` values.

Required add-on options:

- `enable_mqtt_controls` - Enable MQTT discovery and command listener.
- `inverter_sn` - Inverter serial number used in Hypon API payloads.
- `config_put_endpoint` - API path for config writes. Default `/inverter/config`.
- `config_put_method` - API method for config writes. Default `PUT`.
- `mqtt_host` - MQTT broker host (for Home Assistant Mosquitto add-on, use `core-mosquitto`).
- `mqtt_port` - MQTT broker port, default `1883`.
- `mqtt_username` / `mqtt_password` - Optional MQTT auth.
- `mqtt_discovery_prefix` - Discovery prefix, default `homeassistant`.
- `mqtt_base_topic` - Base topic for state/command topics, default `hypon_cloud`.
- `mqtt_apply_on_change` - If `true`, each control change is pushed immediately to Hypon API. If `false`, use the `Apply Selected Slot Settings` button entity.

Quick setup:

1. Install and configure the Mosquitto broker add-on in Home Assistant.
2. Confirm MQTT integration is enabled in Home Assistant.
3. Set add-on options: `inverter_sn`, `enable_mqtt_controls: true`, and MQTT broker credentials/host.
4. Restart this add-on.
5. In Home Assistant, open Devices and find the Hypon inverter device created via MQTT discovery.

How to use from Home Assistant:

- `Slot Number` - Choose which slot (`1` to `4`) you are editing.
- `Enable Disable Slot` - `set` to create/update slot, `disable` to disable selected slot.
- `Battery Slot Mode - Charge/Discharge` - Charge or discharge for the selected slot.
- `Battery Slot Start Time` / `Battery Slot End Time` - Time window for the selected slot.
- `Battery Slot Power` - Power value for the selected slot.
- Day switches: `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Friday`, `Saturday`, `Sunday` - tick on/off to control which days the selected slot runs.
- `Apply Selected Slot Settings` - Send current selected-slot settings to Hypon when `mqtt_apply_on_change` is `false`.
- `Disable Selected Slot` - Sends `disableTimeMode` for the selected slot immediately.
