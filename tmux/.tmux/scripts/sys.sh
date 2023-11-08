#!/usr/bin/env bash
sep="  "

# time
now="$(date '+%Y-%m-%d %H:%M')"

# load (1-min)
load1="$(uptime | awk -F'load average[s]?: ' '{print $2}' 2>/dev/null | cut -d',' -f1)"
[ -z "$load1" ] && load1="n/a"

# memory
if command -v free >/dev/null 2>&1; then
  mem_used="$(free -m | awk '/Mem:/ {print $3}')"
  mem_total="$(free -m | awk '/Mem:/ {print $2}')"
  mem_pct=$(( 100 * mem_used / (mem_total > 0 ? mem_total : 1) ))
  mem_str="${mem_used}/${mem_total}MB ${mem_pct}%"
elif command -v vm_stat >/dev/null 2>&1; then
  # macOS
  pagesize="$(vm_stat | awk '/page size of/ {print $8}')"
  p_active="$(vm_stat | awk '/Pages active/ {gsub("\\.","",$3); print $3}')"
  p_inact="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
  p_spec="$(vm_stat | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')"
  p_free="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
  used=$(( (p_active + p_inact + p_spec) * pagesize / 1024 / 1024 ))
  free=$(( p_free * pagesize / 1024 / 1024 ))
  total=$(( used + free ))
  pct=$(( total > 0 ? (100 * used / total) : 0 ))
  mem_str="${used}/${total}MB ${pct}%"
else
  mem_str="n/a"
fi

# disk (root)
disk_str="$(df -h / 2>/dev/null | awk 'NR==2{print $3 "/" $2 " " $5}')"
[ -z "$disk_str" ] && disk_str="n/a"

# battery
battery="n/a"
if command -v acpi >/dev/null 2>&1; then
  battery="$(acpi -b | awk -F', ' 'NR==1{gsub("%","",$2); print $2"%"}')"
elif command -v pmset >/dev/null 2>&1; then
  battery="$(pmset -g batt | awk -F'; *|%' 'NR==2{print $2"%"}')"
elif [ -d /sys/class/power_supply ]; then
  bat="$(ls /sys/class/power_supply 2>/dev/null | grep -m1 -E '^BAT|^CMB')"
  [ -n "$bat" ] && battery="$(cat "/sys/class/power_supply/$bat/capacity" 2>/dev/null)%"
fi

# active network iface
iface="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
[ -z "$iface" ] && iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
[ -z "$iface" ] && iface="n/a"

# icons + output
printf " %s%s %s%s %s%s🔋 %s%s %s%s %s" \
  "$load1" "$sep" "$mem_str" "$sep" "$disk_str" "$sep" "$battery" "$sep" "$iface" "$sep" "$now"

