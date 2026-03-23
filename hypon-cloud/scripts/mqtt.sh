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
    --arg action "set" \
    --arg mode "$mode" \
    --argjson slot "$timen" \
    --argjson power "$power" \
    --arg start "$start" \
    --arg end "$end" \
    '{
      action: ($action // "set"),
      slot: $slot,
      slots: {
        "1": {mode: $mode, power: $power, start: $start, end: $end},
        "2": {mode: $mode, power: $power, start: $start, end: $end},
        "3": {mode: $mode, power: $power, start: $start, end: $end},
        "4": {mode: $mode, power: $power, start: $start, end: $end}
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

  mqtt_publish "$(mqtt_discovery_topic select hypon_${inverterSn}_timemode_mode)" "$(jq -nc \
    --arg name "Battery Slot Mode" \
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

  mqtt_publish "$(mqtt_discovery_topic number hypon_${inverterSn}_timemode_power)" "$(jq -nc \
    --arg name "Battery Slot Power" \
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

  mqtt_publish "$(mqtt_discovery_topic number hypon_${inverterSn}_timemode_slot)" "$(jq -nc \
    --arg name "Selected Battery Slot" \
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
      cmd_tpl: "{\"field\":\"slot\",\"value\":{{ value }}}",
      min: 1,
      max: 4,
      step: 1,
      mode: "slider",
      avty_t: $avty,
      pl_avail: "online",
      pl_not_avail: "offline",
      dev: $dev
    }')" true

  mqtt_publish "$(mqtt_discovery_topic text hypon_${inverterSn}_timemode_start)" "$(jq -nc \
    --arg name "Battery Slot Start Time" \
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
    --arg name "Battery Slot End Time" \
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

  mqtt_publish "$(mqtt_discovery_topic select hypon_${inverterSn}_timemode_action)" "$(jq -nc \
    --arg name "Battery Slot Action" \
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

  mqtt_publish "$(mqtt_discovery_topic button hypon_${inverterSn}_timemode_apply)" "$(jq -nc \
    --arg name "Apply Selected Slot Settings" \
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
    --arg name "Disable Selected Slot" \
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

mqtt_publish_state() {
  local state
  local slot
  local mode
  local power
  local start
  local end

  state=$(cat "$MQTT_STATE_FILE")
  slot=$(echo "$state" | jq -r '.slot // 1')
  mode=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].mode // "charge"')
  power=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].power // 100')
  start=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].start // "03:30"')
  end=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].end // "05:30"')

  mqtt_publish "$(mqtt_state_topic action)" "$(echo "$state" | jq -r '.action')" true
  mqtt_publish "$(mqtt_state_topic slot)" "$slot" true
  mqtt_publish "$(mqtt_state_topic mode)" "$mode" true
  mqtt_publish "$(mqtt_state_topic power)" "$power" true
  mqtt_publish "$(mqtt_state_topic start)" "$start" true
  mqtt_publish "$(mqtt_state_topic end)" "$end" true
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

  inverterSn=$(bashio::config 'inverter_sn')
  state=$(cat "$MQTT_STATE_FILE")
  action=$(echo "$state" | jq -r '.action // "set"')
  slot=$(echo "$state" | jq -r '.slot // 1')
  mode=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].mode // "charge"')
  power=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].power // 100')
  start=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].start // "03:30"')
  end=$(echo "$state" | jq -r --arg slot "$slot" '.slots[$slot].end // "05:30"')

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
    --arg timeweekday1 "1" \
    --arg timeweekday2 "1" \
    --arg timeweekday3 "1" \
    --arg timeweekday4 "1" \
    --arg timeweekday5 "1" \
    --arg timeweekday6 "1" \
    --arg timeweekday7 "1" \
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

  payload=$(mqtt_build_payload_from_state)
  authToken=$(loginHypon)

  if sendInverterConfigPayload "$authToken" "$payload"; then
    mqtt_publish "$(mqtt_status_topic)" "online" true
  else
    mqtt_publish "$(mqtt_status_topic)" "online" true
  fi
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
        jq --arg value "$value" '.action=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      fi
      ;;
    mode)
      if [ "$value" = "charge" ] || [ "$value" = "discharge" ]; then
        jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {mode:"charge",power:100,start:"03:30",end:"05:30"}) | .slots[.slot|tostring].mode=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      fi
      ;;
    slot)
      value=$(echo "$value" | jq -Rr 'try (tonumber) catch 1 | if . < 1 then 1 elif . > 4 then 4 else . end')
      jq --argjson value "$value" '.slot=$value | (.slots //= {}) | (.slots[$value|tostring] //= {mode:"charge",power:100,start:"03:30",end:"05:30"})' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    power)
      value=$(echo "$value" | jq -Rr 'try (tonumber) catch 100 | if . < 0 then 0 elif . > 10000 then 10000 else . end')
      jq --argjson value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {mode:"charge",power:100,start:"03:30",end:"05:30"}) | .slots[.slot|tostring].power=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    start)
      jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {mode:"charge",power:100,start:"03:30",end:"05:30"}) | .slots[.slot|tostring].start=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
      ;;
    end)
      jq --arg value "$value" '(.slots //= {}) | (.slots[.slot|tostring] //= {mode:"charge",power:100,start:"03:30",end:"05:30"}) | .slots[.slot|tostring].end=$value' "$MQTT_STATE_FILE" > "$MQTT_STATE_FILE.tmp" && mv "$MQTT_STATE_FILE.tmp" "$MQTT_STATE_FILE"
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
  mqtt_publish_discovery
  mqtt_publish_state
  mqtt_publish "$(mqtt_status_topic)" "online" true

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
