#!/usr/bin/with-contenv bashio

declare MQTT_STATE_FILE="/tmp/hypon_timemode_state.json"

mqtt_enabled() {
  local enabled
  enabled=$(bashio::config 'enable_mqtt_controls')
  [ "$enabled" = "true" ]
}

mqtt_get_host() {
  local host
  host=$(bashio::config 'mqtt_host')
  if [ -z "$host" ] || [ "$host" = "null" ]; then
    host="core-mosquitto"
  fi
  echo "$host"
}

mqtt_get_port() {
  local port
  port=$(bashio::config 'mqtt_port')
  if [ -z "$port" ] || [ "$port" = "null" ]; then
    port="1883"
  fi
  echo "$port"
}

mqtt_get_discovery_prefix() {
  local prefix
  prefix=$(bashio::config 'mqtt_discovery_prefix')
  if [ -z "$prefix" ] || [ "$prefix" = "null" ]; then
    prefix="homeassistant"
  fi
  echo "$prefix"
}

mqtt_get_base_topic() {
  local prefix
  prefix=$(bashio::config 'mqtt_base_topic')
  if [ -z "$prefix" ] || [ "$prefix" = "null" ]; then
    prefix="hypon_cloud"
  fi
  echo "$prefix"
}

mqtt_sync_enabled() {
  local enabled
  enabled=$(bashio::config 'mqtt_sync_from_hypon')
  [ "$enabled" = "true" ]
}

mqtt_get_sync_interval() {
  local interval
  interval=$(bashio::config 'mqtt_sync_interval')
  if [ -z "$interval" ] || [ "$interval" = "null" ]; then
    interval=7200
  fi
  echo "$interval"
}

mqtt_publish() {
  local topic=${1}
  local payload=${2}
  local retain=${3:-false}
  local host
  local port
  local username
  local password
  local retainFlag=""

  host=$(mqtt_get_host)
  port=$(mqtt_get_port)
  username=$(bashio::config 'mqtt_username')
  password=$(bashio::config 'mqtt_password')

  if [ "$retain" = "true" ]; then
    retainFlag="-r"
  fi

  if [ -n "$username" ] && [ "$username" != "null" ]; then
    mosquitto_pub -h "$host" -p "$port" -u "$username" -P "$password" $retainFlag -t "$topic" -m "$payload" >/dev/null 2>&1
  else
    mosquitto_pub -h "$host" -p "$port" $retainFlag -t "$topic" -m "$payload" >/dev/null 2>&1
  fi
}

mqtt_unpublish() {
  local topic=${1}
  mqtt_publish "$topic" "" true
}

mqtt_discovery_topic() {
  local component=${1}
  local objectId=${2}
  local discoveryPrefix

  discoveryPrefix=$(mqtt_get_discovery_prefix)
  echo "$discoveryPrefix/$component/$objectId/config"
}

mqtt_command_topic() {
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/command"
}

mqtt_state_topic() {
  local field=${1}
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/state/$field"
}

mqtt_status_topic() {
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/status"
}

mqtt_apply_progress_topic() {
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/apply/in_progress"
}

mqtt_apply_status_topic() {
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/apply/status"
}

mqtt_sync_status_topic() {
  local baseTopic
  local inverterSn

  baseTopic=$(mqtt_get_base_topic)
  inverterSn=$(bashio::config 'inverter_sn')
  echo "$baseTopic/$inverterSn/timemode/sync/status"
}

mqtt_device_json() {
  local inverterSn

  inverterSn=$(bashio::config 'inverter_sn')
  jq -nc \
    --arg identifier "hypon_cloud_$inverterSn" \
    --arg name "Hypon Inverter $inverterSn" \
    '{
      identifiers: [$identifier],
      name: $name,
      manufacturer: "Hypon",
      model: "Cloud Inverter"
    }'
}

mqtt_init_state() {
  local mode
  local timen
  local power
  local start
  local end

  mode="charge"
  timen=1
  power=100
  start="03:30"
  end="05:30"

  jq -nc \
    --arg mode "$mode" \
    --argjson slot "$timen" \
    --argjson power "$power" \
    --arg start "$start" \
    --arg end "$end" \
    '{
      action: "set",
      slot: $slot,
      slots: {
        "1": {action: "set", mode: $mode, power: $power, start: $start, end: $end, weekdays: {day1: 1, day2: 1, day3: 1, day4: 1, day5: 1, day6: 0, day7: 0}},
        "2": {action: "set", mode: $mode, power: $power, start: $start, end: $end, weekdays: {day1: 1, day2: 1, day3: 1, day4: 1, day5: 1, day6: 0, day7: 0}},
        "3": {action: "set", mode: $mode, power: $power, start: $start, end: $end, weekdays: {day1: 1, day2: 1, day3: 1, day4: 1, day5: 1, day6: 0, day7: 0}},
        "4": {action: "set", mode: $mode, power: $power, start: $start, end: $end, weekdays: {day1: 1, day2: 1, day3: 1, day4: 1, day5: 1, day6: 0, day7: 0}}
      }
    }' > "$MQTT_STATE_FILE"
}

mqtt_publish_discovery() {
  local inverterSn
  local cmdTopic
  local statusTopic
  local deviceJson

  inverterSn=$(bashio::config 'inverter_sn')
  cmdTopic=$(mqtt_command_topic)
  statusTopic=$(mqtt_status_topic)
  deviceJson=$(mqtt_device_json)

  mqtt_publish "$(mqtt_discovery_topic select hypon_${inverterSn}_timemode_slot)" "$(jq -nc \
    --arg name "1 Slot Number" \
    --arg uniq "hypon_${inverterSn}_timemode_slot" \
    --arg stat "$(mqtt_state_topic slot)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"slot\",\"value\":\"{{ value }}\"}",
      options: ["1", "2", "3", "4"],
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic binary_sensor hypon_${inverterSn}_timemode_apply_in_progress)" "$(jq -nc \
    --arg name "0 Apply In Progress" \
    --arg uniq "hypon_${inverterSn}_timemode_apply_in_progress" \
    --arg stat "$(mqtt_apply_progress_topic)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      pl_on: "ON",
      pl_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic sensor hypon_${inverterSn}_timemode_apply_status)" "$(jq -nc \
    --arg name "0 Apply Status" \
    --arg uniq "hypon_${inverterSn}_timemode_apply_status" \
    --arg stat "$(mqtt_apply_status_topic)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic sensor hypon_${inverterSn}_timemode_sync_status)" "$(jq -nc \
    --arg name "0 Sync Status" \
    --arg uniq "hypon_${inverterSn}_timemode_sync_status" \
    --arg stat "$(mqtt_sync_status_topic)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic select hypon_${inverterSn}_timemode_action)" "$(jq -nc \
    --arg name "2 Enable Disable Slot" \
    --arg uniq "hypon_${inverterSn}_timemode_action" \
    --arg stat "$(mqtt_state_topic action)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"action\",\"value\":\"{{ value }}\"}",
      options: ["set", "disable"],
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic select hypon_${inverterSn}_timemode_mode)" "$(jq -nc \
    --arg name "3 Slot Mode - Charge/Discharge" \
    --arg uniq "hypon_${inverterSn}_timemode_mode" \
    --arg stat "$(mqtt_state_topic mode)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"mode\",\"value\":\"{{ value }}\"}",
      options: ["charge", "discharge"],
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic text hypon_${inverterSn}_timemode_start)" "$(jq -nc \
    --arg name "4 Slot Start Time" \
    --arg uniq "hypon_${inverterSn}_timemode_start" \
    --arg stat "$(mqtt_state_topic start)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"start\",\"value\":\"{{ value }}\"}",
      pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic text hypon_${inverterSn}_timemode_end)" "$(jq -nc \
    --arg name "5 Slot End Time" \
    --arg uniq "hypon_${inverterSn}_timemode_end" \
    --arg stat "$(mqtt_state_topic end)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"end\",\"value\":\"{{ value }}\"}",
      pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic number hypon_${inverterSn}_timemode_power)" "$(jq -nc \
    --arg name "6 Slot Power" \
    --arg uniq "hypon_${inverterSn}_timemode_power" \
    --arg stat "$(mqtt_state_topic power)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"power\",\"value\":{{ value }}}",
      min: 0,
      max: 10000,
      step: 1,
      mode: "box",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day1)" "$(jq -nc \
    --arg name "7.1 Slot Day Monday" \
    --arg uniq "hypon_${inverterSn}_timemode_day1" \
    --arg stat "$(mqtt_state_topic day1)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day1\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day2)" "$(jq -nc \
    --arg name "7.2 Slot Day Tuesday" \
    --arg uniq "hypon_${inverterSn}_timemode_day2" \
    --arg stat "$(mqtt_state_topic day2)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day2\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day3)" "$(jq -nc \
    --arg name "7.3 Slot Day Wednesday" \
    --arg uniq "hypon_${inverterSn}_timemode_day3" \
    --arg stat "$(mqtt_state_topic day3)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day3\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day4)" "$(jq -nc \
    --arg name "7.4 Slot Day Thursday" \
    --arg uniq "hypon_${inverterSn}_timemode_day4" \
    --arg stat "$(mqtt_state_topic day4)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day4\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day5)" "$(jq -nc \
    --arg name "7.5 Slot Day Friday" \
    --arg uniq "hypon_${inverterSn}_timemode_day5" \
    --arg stat "$(mqtt_state_topic day5)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day5\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day6)" "$(jq -nc \
    --arg name "7.6 Slot Day Saturday" \
    --arg uniq "hypon_${inverterSn}_timemode_day6" \
    --arg stat "$(mqtt_state_topic day6)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day6\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic switch hypon_${inverterSn}_timemode_day7)" "$(jq -nc \
    --arg name "7.7 Slot Day Sunday" \
    --arg uniq "hypon_${inverterSn}_timemode_day7" \
    --arg stat "$(mqtt_state_topic day7)" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      cmd_t: $cmd,
      cmd_tpl: "{\"field\":\"day7\",\"value\":\"{{ value }}\"}",
      pl_on: "ON",
      pl_off: "OFF",
      stat_on: "ON",
      stat_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic binary_sensor hypon_${inverterSn}_timemode_slot1_enabled)" "$(jq -nc \
    --arg name "10.1 Slot 1 Enabled" \
    --arg uniq "hypon_${inverterSn}_timemode_slot1_enabled" \
    --arg stat "$(mqtt_state_topic slot1_enabled)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      pl_on: "ON",
      pl_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic binary_sensor hypon_${inverterSn}_timemode_slot2_enabled)" "$(jq -nc \
    --arg name "10.2 Slot 2 Enabled" \
    --arg uniq "hypon_${inverterSn}_timemode_slot2_enabled" \
    --arg stat "$(mqtt_state_topic slot2_enabled)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      pl_on: "ON",
      pl_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic binary_sensor hypon_${inverterSn}_timemode_slot3_enabled)" "$(jq -nc \
    --arg name "10.3 Slot 3 Enabled" \
    --arg uniq "hypon_${inverterSn}_timemode_slot3_enabled" \
    --arg stat "$(mqtt_state_topic slot3_enabled)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      pl_on: "ON",
      pl_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic binary_sensor hypon_${inverterSn}_timemode_slot4_enabled)" "$(jq -nc \
    --arg name "10.4 Slot 4 Enabled" \
    --arg uniq "hypon_${inverterSn}_timemode_slot4_enabled" \
    --arg stat "$(mqtt_state_topic slot4_enabled)" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      stat_t: $stat,
      pl_on: "ON",
      pl_off: "OFF",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic button hypon_${inverterSn}_timemode_apply)" "$(jq -nc \
    --arg name "8 Apply Selected Slot Settings" \
    --arg uniq "hypon_${inverterSn}_timemode_apply" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      cmd_t: $cmd,
      pl_prs: "{\"field\":\"apply\",\"value\":\"apply\"}",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic button hypon_${inverterSn}_timemode_disable_slot)" "$(jq -nc \
    --arg name "9 Disable Selected Slot" \
    --arg uniq "hypon_${inverterSn}_timemode_disable_slot" \
    --arg cmd "$cmdTopic" \
    --arg avty "$statusTopic" \
    --argjson dev "$deviceJson" \
    '{
      name: $name,
      uniq_id: $uniq,
      cmd_t: $cmd,
      pl_prs: "{\"field\":\"disable\",\"value\":\"disable\"}",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true
}

mqtt_cleanup_legacy_discovery() {
  local inverterSn

  inverterSn=$(bashio::config 'inverter_sn')

  # Remove old slot-number entity if it was discovered as a number (slider).
  mqtt_unpublish "$(mqtt_discovery_topic number hypon_${inverterSn}_timemode_slot)"
}

mqtt_publish_state() {
  local state
  local slot
  local action
  local mode
  local power
  local start
  local end
  local day1
  local day2
  local day3
  local day4
  local day5
  local day6
  local day7
  local slot1_enabled
  local slot2_enabled
  local slot3_enabled
  local slot4_enabled

  state=$(cat "$MQTT_STATE_FILE")
  slot=$(echo "$state" | jq -r '.slot // 1')
  action=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].action // .action // "set"')
  mode=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].mode // "charge"')
  power=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].power // 100')
  start=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].start // "03:30"')
  end=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].end // "05:30"')
  day1=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day1 // 0) == 1 then "ON" else "OFF" end')
  day2=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day2 // 0) == 1 then "ON" else "OFF" end')
  day3=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day3 // 0) == 1 then "ON" else "OFF" end')
  day4=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day4 // 0) == 1 then "ON" else "OFF" end')
  day5=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day5 // 0) == 1 then "ON" else "OFF" end')
  day6=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day6 // 0) == 1 then "ON" else "OFF" end')
  day7=$(echo "$state" | jq -r --arg slot "$slot" 'if (.slots[$slot].weekdays.day7 // 0) == 1 then "ON" else "OFF" end')
  slot1_enabled=$(echo "$state" | jq -r 'if ((.slots["1"].action // "set") == "disable") then "OFF" else "ON" end')
  slot2_enabled=$(echo "$state" | jq -r 'if ((.slots["2"].action // "set") == "disable") then "OFF" else "ON" end')
  slot3_enabled=$(echo "$state" | jq -r 'if ((.slots["3"].action // "set") == "disable") then "OFF" else "ON" end')
  slot4_enabled=$(echo "$state" | jq -r 'if ((.slots["4"].action // "set") == "disable") then "OFF" else "ON" end')

  mqtt_publish "$(mqtt_state_topic action)" "$action" true
  mqtt_publish "$(mqtt_state_topic slot)" "$slot" true
  mqtt_publish "$(mqtt_state_topic mode)" "$mode" true
  mqtt_publish "$(mqtt_state_topic power)" "$power" true
  mqtt_publish "$(mqtt_state_topic start)" "$start" true
  mqtt_publish "$(mqtt_state_topic end)" "$end" true
  mqtt_publish "$(mqtt_state_topic day1)" "$day1" true
  mqtt_publish "$(mqtt_state_topic day2)" "$day2" true
  mqtt_publish "$(mqtt_state_topic day3)" "$day3" true
  mqtt_publish "$(mqtt_state_topic day4)" "$day4" true
  mqtt_publish "$(mqtt_state_topic day5)" "$day5" true
  mqtt_publish "$(mqtt_state_topic day6)" "$day6" true
  mqtt_publish "$(mqtt_state_topic day7)" "$day7" true
  mqtt_publish "$(mqtt_state_topic slot1_enabled)" "$slot1_enabled" true
  mqtt_publish "$(mqtt_state_topic slot2_enabled)" "$slot2_enabled" true
  mqtt_publish "$(mqtt_state_topic slot3_enabled)" "$slot3_enabled" true
  mqtt_publish "$(mqtt_state_topic slot4_enabled)" "$slot4_enabled" true
}

mqtt_build_payload_from_state() {
  local inverterSn
  local state
  local action
  local slot
  local mode
  local power
  local start
  local end
  local day1
  local day2
  local day3
  local day4
  local day5
  local day6
  local day7

  inverterSn=$(bashio::config 'inverter_sn')
  state=$(cat "$MQTT_STATE_FILE")
  slot=$(echo "$state" | jq -r '.slot // 1')
  action=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].action // .action // "set"')
  mode=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].mode // "charge"')
  power=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].power // 100')
  start=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].start // "03:30"')
  end=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].end // "05:30"')
  day1=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day1 // 1')
  day2=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day2 // 1')
  day3=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day3 // 1')
  day4=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day4 // 1')
  day5=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day5 // 1')
  day6=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day6 // 0')
  day7=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].weekdays.day7 // 0')

  if [ "$action" = "disable" ]; then
    jq -nc --arg invsn "$inverterSn" --arg configname "disableTimeMode" --argjson timen "$slot" '{invsn:$invsn,configname:$configname,timen:$timen}'
    return
  fi

  if [ "$mode" = "discharge" ]; then
    mode="1"
  else
    mode="0"
  fi

  jq -nc \
    --arg invsn "$inverterSn" \
    --arg configname "TimeMode" \
    --arg timestarttime "$start" \
    --arg timeendtime "$end" \
    --arg old_time_enable "0" \
    --arg time_enable "1" \
    --arg timemode "$mode" \
    --arg timen "$slot" \
    --arg timepower "$power" \
    --arg timeweekday1 "$day1" \
    --arg timeweekday2 "$day2" \
    --arg timeweekday3 "$day3" \
    --arg timeweekday4 "$day4" \
    --arg timeweekday5 "$day5" \
    --arg timeweekday6 "$day6" \
    --arg timeweekday7 "$day7" \
    '{
      invsn: $invsn,
      configname: $configname,
      timestarttime: $timestarttime,
      timeendtime: $timeendtime,
      old_time_enable: $old_time_enable,
      time_enable: $time_enable,
      timemode: (try ($timemode | tonumber) catch 0),
      timen: (try ($timen | tonumber) catch 1),
      timepower: (try ($timepower | tonumber) catch 100),
      timeweekday1: (try ($timeweekday1 | tonumber) catch 1),
      timeweekday2: (try ($timeweekday2 | tonumber) catch 1),
      timeweekday3: (try ($timeweekday3 | tonumber) catch 1),
      timeweekday4: (try ($timeweekday4 | tonumber) catch 1),
      timeweekday5: (try ($timeweekday5 | tonumber) catch 1),
      timeweekday6: (try ($timeweekday6 | tonumber) catch 1),
      timeweekday7: (try ($timeweekday7 | tonumber) catch 1)
    }'
}

mqtt_apply_state() {
  local authToken
  local payload
  local inverterSn
  local waitTimeoutSeconds=60
  local waitIntervalSeconds=2

  inverterSn=$(bashio::config 'inverter_sn')

  payload=$(mqtt_build_payload_from_state)
  mqtt_publish "$(mqtt_apply_progress_topic)" "ON" true
  mqtt_publish "$(mqtt_apply_status_topic)" "Sending update request" true

  authToken=$(loginHypon)
  if [ -z "$authToken" ] || [ "$authToken" = "null" ]; then
    mqtt_publish "$(mqtt_apply_status_topic)" "Authentication failed" true
    mqtt_publish "$(mqtt_apply_progress_topic)" "OFF" true
    return 1
  fi

  if sendInverterConfigPayload "$authToken" "$payload"; then
    mqtt_publish "$(mqtt_apply_status_topic)" "Waiting for inverter response endpoint" true
    if waitForInverterResponse200 "$authToken" "$inverterSn" "$waitTimeoutSeconds" "$waitIntervalSeconds"; then
      mqtt_publish "$(mqtt_apply_status_topic)" "Update confirmed by inverter response endpoint" true
      mqtt_publish "$(mqtt_apply_progress_topic)" "OFF" true
      return 0
    fi

    mqtt_publish "$(mqtt_apply_status_topic)" "Timed out waiting for inverter response endpoint" true
    mqtt_publish "$(mqtt_apply_progress_topic)" "OFF" true
    return 1
  else
    mqtt_publish "$(mqtt_apply_status_topic)" "Apply request failed" true
    mqtt_publish "$(mqtt_apply_progress_topic)" "OFF" true
    return 1
  fi
}

mqtt_sync_slot_from_hypon() {
  local authToken=${1}
  local slot=${2}
  local inverterSn
  local response
  local httpCode
  local body
  local mode
  local power
  local start
  local end
  local action
  local day1
  local day2
  local day3
  local day4
  local day5
  local day6
  local day7

  inverterSn=$(bashio::config 'inverter_sn')
  response=$(curl -s "$HYPON_URL/inverter/$inverterSn/config/TimeMode$slot" \
    -H "$ACCEPT_HEADER" \
    -H 'User-Agent: Mozilla/5.0' \
    -H "authorization: Bearer $authToken" \
    --write-out '\n%{http_code}')

  httpCode=${response##*$'\n'}
  body=${response%$'\n'*}

  if [ "$httpCode" != "200" ]; then
    bashio::log.debug "Skipping TimeMode$slot sync, HTTP $httpCode"
    return 1
  fi

  if ! echo "$body" | jq -e . >/dev/null 2>&1; then
    bashio::log.debug "Skipping TimeMode$slot sync, invalid JSON"
    return 1
  fi

  mode=$(echo "$body" | jq -r 'if ((.data.timemode // .timemode // 0) | tonumber) == 1 then "discharge" else "charge" end')
  power=$(echo "$body" | jq -r '(.data.timepower // .timepower // 100) | tonumber')
  start=$(echo "$body" | jq -r '.data.timestarttime // .timestarttime // "03:30"')
  end=$(echo "$body" | jq -r '.data.timeendtime // .timeendtime // "05:30"')
  action=$(echo "$body" | jq -r 'if ((.data.time_enable // .time_enable // 1) | tonumber) == 0 then "disable" else "set" end')
  day1=$(echo "$body" | jq -r '(.data.timeweekday1 // .timeweekday1 // 1) | tonumber')
  day2=$(echo "$body" | jq -r '(.data.timeweekday2 // .timeweekday2 // 1) | tonumber')
  day3=$(echo "$body" | jq -r '(.data.timeweekday3 // .timeweekday3 // 1) | tonumber')
  day4=$(echo "$body" | jq -r '(.data.timeweekday4 // .timeweekday4 // 1) | tonumber')
  day5=$(echo "$body" | jq -r '(.data.timeweekday5 // .timeweekday5 // 1) | tonumber')
  day6=$(echo "$body" | jq -r '(.data.timeweekday6 // .timeweekday6 // 0) | tonumber')
  day7=$(echo "$body" | jq -r '(.data.timeweekday7 // .timeweekday7 // 0) | tonumber')

  jq \
    --arg slot "$slot" \
    --arg mode "$mode" \
    --argjson power "$power" \
    --arg start "$start" \
    --arg end "$end" \
    --arg action "$action" \
    --argjson day1 "$day1" \
    --argjson day2 "$day2" \
    --argjson day3 "$day3" \
    --argjson day4 "$day4" \
    --argjson day5 "$day5" \
    --argjson day6 "$day6" \
    --argjson day7 "$day7" \
    '(.slots //= {})
    | (.slots[$slot] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}})
    | .slots[$slot].mode = $mode
    | .slots[$slot].action = $action
    | .slots[$slot].power = $power
    | .slots[$slot].start = $start
    | .slots[$slot].end = $end
    | (.slots[$slot].weekdays //= {day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0})
    | .slots[$slot].weekdays.day1 = $day1
    | .slots[$slot].weekdays.day2 = $day2
    | .slots[$slot].weekdays.day3 = $day3
    | .slots[$slot].weekdays.day4 = $day4
    | .slots[$slot].weekdays.day5 = $day5
    | .slots[$slot].weekdays.day6 = $day6
    | .slots[$slot].weekdays.day7 = $day7
    | if (.slot|tostring) == $slot then .action = $action else . end' \
    "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"

  return 0
}

mqtt_sync_from_hypon() {
  local authToken
  local slot
  local syncedCount=0

  if ! mqtt_sync_enabled; then
    return 0
  fi

  mqtt_publish "$(mqtt_sync_status_topic)" "Sync started" true

  authToken=$(loginHypon)
  if [ -z "$authToken" ] || [ "$authToken" = "null" ]; then
    bashio::log.error "MQTT sync: unable to authenticate to Hypon"
    mqtt_publish "$(mqtt_sync_status_topic)" "Sync failed: authentication error" true
    return 1
  fi

  for slot in 1 2 3 4
  do
    mqtt_publish "$(mqtt_sync_status_topic)" "Syncing TimeMode$slot" true
    if mqtt_sync_slot_from_hypon "$authToken" "$slot"; then
      syncedCount=$((syncedCount + 1))
    fi
  done

  mqtt_publish_state
  mqtt_publish "$(mqtt_sync_status_topic)" "Sync completed: $syncedCount/4 slots updated" true
  return 0
}

startMqttSyncLoop() {
  local interval

  if ! mqtt_sync_enabled; then
    return 0
  fi

  interval=$(mqtt_get_sync_interval)
  bashio::log.info "Starting MQTT Hypon config sync loop every ${interval}s"

  while true
  do
    mqtt_sync_from_hypon || true
    sleep "$interval"
  done
}

mqtt_update_state_field() {
  local field=${1}
  local value=${2}
  local slot

  if [ ! -f "$MQTT_STATE_FILE" ]; then
    mqtt_init_state
  fi

  case "$field" in
    action)
      if [ "$value" = "set" ] || [ "$value" = "disable" ]; then
        jq --arg value "$value" '(.slots //= {})
          | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}})
          | .slots[.slot|tostring].action=$value
          | .action=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      fi
      ;;
    mode)
      if [ "$value" = "charge" ] || [ "$value" = "discharge" ]; then
        jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}}) | .slots[.slot|tostring].mode=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      fi
      ;;
    slot)
      value=$(echo "$value" | jq -Rr 'try (tonumber) catch 1 | if . < 1 then 1 elif . > 4 then 4 else . end')
      jq --argjson value "$value" '.slot=$value
        | (.slots //= {})
        | (.slots[$value|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}})
        | .action = (.slots[$value|tostring].action // .action // "set")' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    power)
      value=$(echo "$value" | jq -Rr 'try (tonumber) catch 100 | if . < 0 then 0 elif . > 10000 then 10000 else . end')
      jq --argjson value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}}) | .slots[.slot|tostring].power=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    start)
      jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}}) | .slots[.slot|tostring].start=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    end)
      jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}}) | .slots[.slot|tostring].end=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    day1|day2|day3|day4|day5|day6|day7)
      if [ "$value" = "ON" ] || [ "$value" = "on" ] || [ "$value" = "1" ] || [ "$value" = "true" ] || [ "$value" = "True" ]; then
        value=1
      else
        value=0
      fi
      jq --arg field "$field" --argjson value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {action:"set",mode:"charge",power:100,start:"03:30",end:"05:30",weekdays:{day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}}) | (.slots[.slot|tostring].weekdays //= {day1:1,day2:1,day3:1,day4:1,day5:1,day6:0,day7:0}) | .slots[.slot|tostring].weekdays[$field]=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
  esac
}

mqtt_handle_command() {
  local payload=${1}
  local field
  local value
  local applyOnChange

  if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
    bashio::log.error "Ignoring invalid MQTT command payload: $payload"
    return
  fi

  field=$(echo "$payload" | jq -r '.field // empty')
  value=$(echo "$payload" | jq -r '.value // empty')

  if [ -z "$field" ]; then
    bashio::log.error "Ignoring MQTT command without field"
    return
  fi

  case "$field" in
    apply)
      mqtt_apply_state
      mqtt_publish_state
      return
      ;;
    disable)
      mqtt_update_state_field "action" "disable"
      mqtt_apply_state
      mqtt_publish_state
      return
      ;;
  esac

  mqtt_update_state_field "$field" "$value"
  mqtt_publish_state

  applyOnChange=$(bashio::config 'mqtt_apply_on_change')
  if [ "$applyOnChange" = "true" ]; then
    mqtt_apply_state
  fi
}

startMqttControlLoop() {
  local inverterSn
  local host
  local port
  local username
  local password
  local commandTopic

  if ! mqtt_enabled; then
    return 0
  fi

  inverterSn=$(bashio::config 'inverter_sn')
  if [ -z "$inverterSn" ] || [ "$inverterSn" = "null" ]; then
    bashio::log.error "MQTT controls enabled but inverter_sn is empty"
    return 1
  fi

  if ! command -v mosquitto_pub >/dev/null 2>&1 || ! command -v mosquitto_sub >/dev/null 2>&1; then
    bashio::log.error "MQTT controls enabled but mosquitto clients are unavailable"
    return 1
  fi

  host=$(mqtt_get_host)
  port=$(mqtt_get_port)
  username=$(bashio::config 'mqtt_username')
  password=$(bashio::config 'mqtt_password')
  commandTopic=$(mqtt_command_topic)

  mqtt_init_state
  mqtt_cleanup_legacy_discovery
  mqtt_publish_discovery
  mqtt_sync_from_hypon || true
  mqtt_publish_state
  mqtt_publish "$(mqtt_status_topic)" "online" true
  mqtt_publish "$(mqtt_apply_progress_topic)" "OFF" true
  mqtt_publish "$(mqtt_apply_status_topic)" "Idle" true
  mqtt_publish "$(mqtt_sync_status_topic)" "Idle" true
  startMqttSyncLoop &

  bashio::log.info "Starting MQTT control loop on topic $commandTopic"

  if [ -n "$username" ] && [ "$username" != "null" ]; then
    mosquitto_sub -h "$host" -p "$port" -u "$username" -P "$password" -t "$commandTopic" -F '%p' | while IFS= read -r payload
    do
      mqtt_handle_command "$payload"
    done
  else
    mosquitto_sub -h "$host" -p "$port" -t "$commandTopic" -F '%p' | while IFS= read -r payload
    do
      mqtt_handle_command "$payload"
    done
  fi
}
