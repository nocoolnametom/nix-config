# nas-status - live health dashboard for a NixOS NAS
#
# Layout and refresh approach adapted from nixnas-status in
# https://github.com/iamjairo/ugreennas-dots (MIT). Rewritten to discover the
# hardware instead of hard-coding it, to read a btrfs pool instead of mdadm,
# and to show which services are using the disks and the network.
#
#   nas-status              refresh every 5 s (Ctrl+C to quit)
#   nas-status -r 3         refresh every 3 s
#   nas-status --once       print one snapshot and exit
#   nas-status -n 10        show the 10 busiest services (default 5)
#   sudo nas-status         adds SMART health/temps, btrfs errors and scrub
#                           status, and Docker container names
#
# Per-service numbers come from systemd's own accounting (`systemctl show`):
# CPUUsageNSec, MemoryCurrent, IOReadBytes/IOWriteBytes (cgroup io.stat) and
# IPIngressBytes/IPEgressBytes (DefaultIPAccounting, on by default in NixOS).
# Rates are the difference between two samples SAMPLE seconds apart.
#
# Settings arrive as environment variables from the Nix wrapper:
#   NAS_STATUS_POOL  a path on the data pool (any subvolume), shown first
#   NAS_STATUS_POOL_LABEL  name to show for it (e.g. the pool's parent dir)
#   NAS_STATUS_JOBS  space-separated units whose last run is reported
#   NAS_STATUS_MOUNTS space-separated extra mount points to show

set -uo pipefail

REFRESH=5
ONCE=false
SAMPLE=2
TOP=5
while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --refresh)
		REFRESH="$2"
		shift 2
		;;
	-n | --top)
		TOP="$2"
		shift 2
		;;
	--once)
		ONCE=true
		shift
		;;
	-h | --help)
		printf '%s\n' "usage: nas-status [-r SECONDS] [-n TOP] [--once]" \
			"  -r, --refresh N   redraw every N seconds (default 5)" \
			"  -n, --top N       how many services to list (default 5)" \
			"  --once            print one snapshot and exit" \
			"  run with sudo to add SMART health, btrfs errors, scrub status and container names"
		exit 0
		;;
	*) shift ;;
	esac
done
((REFRESH < SAMPLE + 1)) && REFRESH=$((SAMPLE + 1))

POOL="${NAS_STATUS_POOL:-}"
JOBS="${NAS_STATUS_JOBS:-}"
MOUNTS="${NAS_STATUS_MOUNTS:-/ /nix}"
IS_ROOT=false
[[ $EUID -eq 0 ]] && IS_ROOT=true

if [[ -t 1 ]]; then
	RST=$'\e[0m' BLD=$'\e[1m' DIM=$'\e[2m' GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m'
	CYN=$'\e[36m' BCYN=$'\e[1;36m' BWHT=$'\e[1;37m'
else
	RST="" BLD="" DIM="" GRN="" YLW="" RED="" CYN="" BCYN="" BWHT=""
fi
W=96

# ── helpers ─────────────────────────────────────────────────────────────────

hr() { printf '  %s%s%s\n' "$DIM" "$(printf '─%.0s' $(seq 1 $((W - 4))))" "$RST"; }
hdr() { printf '\n  %s━━ %s%s %s%s%s\n' "$BCYN" "$1" "$RST" "$DIM" "${2:-}" "$RST"; }

# human-readable bytes / bytes-per-second
hb() { awk -v b="${1:-0}" 'BEGIN{split("B KiB MiB GiB TiB PiB",u," "); i=1; while (b>=1024 && i<6){b/=1024;i++} printf (i==1?"%d %s":"%.1f %s"), b, u[i]}'; }
hr_rate() { awk -v b="${1:-0}" 'BEGIN{ if (b<1) {print "-"; exit} split("B/s KiB/s MiB/s GiB/s",u," "); i=1; while (b>=1024 && i<4){b/=1024;i++} printf (i==1?"%d %s":"%.1f %s"), b, u[i]}'; }

# colour a value by thresholds: col value warn crit
col() { awk -v v="${1:-0}" -v w="$2" -v c="$3" -v g="$GRN" -v y="$YLW" -v r="$RED" 'BEGIN{printf "%s", (v>=c?r:(v>=w?y:g))}'; }

bar() { # used total width
	local used=${1:-0} total=${2:-1} width=${3:-20} pct filled
	pct=$(awk -v u="$used" -v t="$total" 'BEGIN{printf "%d", (t>0? u*100/t : 0)}')
	filled=$((pct * width / 100))
	printf '%s' "$(col "$pct" 80 95)"
	((filled > 0)) && printf '█%.0s' $(seq 1 "$filled")
	printf '%s' "$DIM"
	((width - filled > 0)) && printf '░%.0s' $(seq 1 $((width - filled)))
	printf '%s %3d%%' "$RST" "$pct"
}

dot() { case "$1" in active | PASSED | success | ok | running) printf '%s●%s' "$GRN" "$RST" ;; standby | activating | inactive) printf '%s●%s' "$DIM" "$RST" ;; *) printf '%s●%s' "$RED" "$RST" ;; esac }

physical_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk" && $1 !~ /^(zram|loop|ram)/{print $1}'; }
physical_nics() { for n in /sys/class/net/*; do
	n=${n##*/}
	[[ $n =~ ^(lo|veth|br-|docker|virbr) ]] || echo "$n"
done; }

# ── sampling ────────────────────────────────────────────────────────────────

declare -A D0 D1 N0 N1 U0 U1
CPU0="" CPU1=""

# "activating" catches one-shot jobs (backups, syncs) while they run.
running_units() { systemctl list-units --type=service,scope --state=running,activating --no-legend --plain 2>/dev/null | awk '{print $1}'; }

# d/n/u/c are namerefs to the caller's arrays, which shellcheck cannot follow:
# assignments look unused (SC2034) and the associative keys look arithmetic (SC2004).
# shellcheck disable=SC2034,SC2004
snap() { # snap <D> <N> <U> <cpuvar>
	local -n d=$1 n=$2 u=$3 c=$4
	local dev f nic
	c=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
	for dev in "${DISKS[@]}"; do
		f=/sys/block/$dev/stat
		# sectors read, sectors written, ms doing I/O
		[[ -r $f ]] && d[$dev]=$(awk '{print $3*512, $7*512, $10}' "$f")
	done
	for nic in "${NICS[@]}"; do
		n[$nic]="$(cat "/sys/class/net/$nic/statistics/rx_bytes" 2>/dev/null || echo 0) $(cat "/sys/class/net/$nic/statistics/tx_bytes" 2>/dev/null || echo 0)"
	done
	# Id cpu mem ior iow ipin ipout, one line per running unit
	while read -r id rest; do u[$id]=$rest; done < <(
		# shellcheck disable=SC2046 # one word per unit name is intended
		systemctl show -p Id,CPUUsageNSec,MemoryCurrent,IOReadBytes,IOWriteBytes,IPIngressBytes,IPEgressBytes -- $(running_units) 2>/dev/null |
			awk -F= 'function n(x){return (x ~ /^[0-9]+$/ && x < 18446744073709551615) ? x : 0}
        /^Id=/{id=$2} /^CPUUsageNSec=/{c=n($2)} /^MemoryCurrent=/{m=n($2)}
        /^IOReadBytes=/{r=n($2)} /^IOWriteBytes=/{w=n($2)} /^IPIngressBytes=/{i=n($2)}
        /^IPEgressBytes=/{o=n($2)}
        /^$/{ if (id!="") print id, c, m, r, w, i, o; id="" }
        END{ if (id!="") print id, c, m, r, w, i, o }'
	)
}

declare -A CTR
container_names() {
	CTR=()
	$IS_ROOT && command -v docker >/dev/null 2>&1 || return 0
	while read -r cid name; do CTR["docker-$cid.scope"]=$name; done < <(docker ps --no-trunc --format '{{.ID}} {{.Names}}' 2>/dev/null)
}

# ── render ──────────────────────────────────────────────────────────────────

render() {
	local dt=$SAMPLE ncpu
	ncpu=$(nproc)

	# header
	local now hn up kernel gen
	now=$(date '+%Y-%m-%d %H:%M:%S')
	hn=$(hostname)
	up=$(awk '{s=$1; d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60); if (d>0) printf "%dd %dh %02dm", d, h, m; else printf "%dh %02dm", h, m}' /proc/uptime)
	kernel=$(uname -r)
	gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -o '[0-9]\+' | tail -1)
	printf '  %s%s%s %s// health%s%*s%s%s%s\n' "$BWHT" "${hn^^}" "$RST" "$DIM" "$RST" $((W - 16 - ${#hn} - ${#now})) "" "$DIM" "$now" "$RST"
	hr

	# system
	local cpu_pct mem_t mem_a sw_t sw_f l1 l5 l15
	cpu_pct=$(awk -v a="$CPU0" -v b="$CPU1" 'BEGIN{split(a,x," "); split(b,y," "); t=y[1]-x[1]; i=y[2]-x[2]; printf "%d", (t>0? (t-i)*100/t : 0)}')
	read -r mem_t mem_a sw_t sw_f < <(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} /^SwapTotal/{st=$2} /^SwapFree/{sf=$2} END{print t*1024, a*1024, st*1024, sf*1024}' /proc/meminfo)
	read -r l1 l5 l15 _ </proc/loadavg
	hdr "SYSTEM"
	printf '  CPU  %s%3d%%%s %s ' "$(col "$cpu_pct" 70 90)" "$cpu_pct" "$RST" "$(bar "$cpu_pct" 100 16)"
	printf ' %sload%s %s %s %s  %s│%s %d cores  %s│%s up %s  %s│%s gen #%s  %s\n' "$DIM" "$RST" "$l1" "$l5" "$l15" "$DIM" "$RST" "$ncpu" "$DIM" "$RST" "$up" "$DIM" "$RST" "${gen:-?}" "$kernel"
	printf '  RAM  %s / %s  %s' "$(hb $((mem_t - mem_a)))" "$(hb "$mem_t")" "$(bar $((mem_t - mem_a)) "$mem_t" 16)"
	((sw_t > 0)) && printf '   %sswap%s %s / %s' "$DIM" "$RST" "$(hb $((sw_t - sw_f)))" "$(hb "$sw_t")"
	printf '\n'

	# temperatures and fans (hwmon; no root needed)
	hdr "TEMPS & FANS"
	local line="" h name lbl t v
	for h in /sys/class/hwmon/hwmon*; do
		name=$(cat "$h/name" 2>/dev/null)
		case $name in
		coretemp)
			for t in "$h"/temp*_label; do
				[[ $(cat "$t") == Package* ]] && v=$(($(cat "${t%_label}_input") / 1000)) && line+="$(printf 'CPU %s%d°C%s  ' "$(col "$v" 75 90)" "$v" "$RST")"
			done
			;;
		nvme)
			v=$(($(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000))
			lbl=$(basename "$(readlink -f "$h/device" 2>/dev/null)")
			line+="$(printf '%s %s%d°C%s  ' "${lbl:-nvme}" "$(col "$v" 60 70)" "$v" "$RST")"
			;;
		acpitz | spd5118 | enp* | eth*)
			v=$(($(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000))
			[[ $name == spd5118 ]] && name=RAM
			[[ $name == acpitz ]] && name=ACPI
			line+="$(printf '%s %s%d°C%s  ' "$name" "$(col "$v" 70 85)" "$v" "$RST")"
			;;
		it8* | nct* | f71*)
			for t in "$h"/temp[0-9]_input; do
				v=$(($(cat "$t") / 1000))
				((v > 0 && v < 120)) && line+="$(printf 'board%s %s%d°C%s  ' "$(basename "$t" _input | tr -dc 0-9)" "$(col "$v" 60 75)" "$v" "$RST")"
			done
			for t in "$h"/fan[0-9]_input; do
				v=$(cat "$t")
				line+="$(printf '%sfan%s %s%d rpm%s  ' "$CYN" "$(basename "$t" _input | tr -dc 0-9)" "$BLD" "$v" "$RST")"
			done
			;;
		esac
	done
	printf '  %s\n' "$line"

	# network
	hdr "NETWORK"
	local nic a b rx tx ip speed
	for nic in "${NICS[@]}"; do
		read -r a b <<<"${N0[$nic]:-0 0}"
		read -r rx tx <<<"${N1[$nic]:-0 0}"
		[[ $(cat "/sys/class/net/$nic/operstate" 2>/dev/null) == down ]] && continue
		ip=$(ip -4 -br addr show "$nic" 2>/dev/null | awk '{print $3}')
		speed=$(cat "/sys/class/net/$nic/speed" 2>/dev/null || true)
		[[ -n $speed && $speed -gt 0 ]] && speed="${speed} Mb/s" || speed=""
		printf '  %-11s %-18s %-10s  in %s%10s%s   out %s%10s%s\n' "$nic" "${ip:--}" "$speed" \
			"$BCYN" "$(hr_rate $(((rx - a) / dt)))" "$RST" "$BCYN" "$(hr_rate $(((tx - b) / dt)))" "$RST"
	done

	# storage: free space
	hdr "STORAGE" "free space"
	# One row per filesystem: mounts on the same device (btrfs subvolumes such
	# as / /nix /persist) share their numbers, so their names are joined.
	local m dev size used avail free_est
	local -A fs_names=() fs_line=()
	local -a fs_order=()
	for m in $POOL $MOUNTS; do
		[[ -e $m ]] || continue
		read -r dev size used avail < <(df -B1 --output=source,size,used,avail "$m" 2>/dev/null | tail -1)
		[[ -z ${dev:-} ]] && continue
		if [[ -z ${fs_line[$dev]:-} ]]; then
			fs_order+=("$dev")
			free_est=""
			if $IS_ROOT && [[ $m == "$POOL" ]]; then
				free_est=$(btrfs filesystem usage -b "$m" 2>/dev/null | awk '/Free \(estimated\)/{print $3; exit}')
				[[ -n $free_est ]] && avail=$free_est
			fi
			fs_line[$dev]="$(printf '%9s  %s  free %s%s%s' "$(hb "$size")" "$(bar "$used" "$size" 24)" "$GRN" "$(hb "$avail")" "$RST")"
			fs_names[$dev]=$m
			[[ $m == "$POOL" ]] && fs_names[$dev]=${NAS_STATUS_POOL_LABEL:-$m}
		else
			fs_names[$dev]+=" $m"
		fi
	done
	for dev in "${fs_order[@]}"; do
		printf '  %-18s %s\n' "${fs_names[$dev]:0:18}" "${fs_line[$dev]}"
	done

	# disks: activity, and SMART when root
	hdr "DISKS" "$($IS_ROOT || echo '(run with sudo for SMART health and drive temps)')"
	printf '  %s%-8s %-24s %8s %11s %11s %5s  %-7s %5s %7s%s\n' "$DIM" dev model size read write busy health temp hours "$RST"
	local dev r0 w0 t0 r1 w1 t1 busy model sz health temp hours sm
	for dev in "${DISKS[@]}"; do
		read -r r0 w0 t0 <<<"${D0[$dev]:-0 0 0}"
		read -r r1 w1 t1 <<<"${D1[$dev]:-0 0 0}"
		busy=$(((t1 - t0) / (dt * 10)))
		((busy > 100)) && busy=100
		model=$(tr -s ' ' <"/sys/block/$dev/device/model" 2>/dev/null | cut -c1-24)
		sz=$(hb $(($(cat "/sys/block/$dev/size") * 512)))
		health="" temp="" hours=""
		if $IS_ROOT; then
			# -n standby: report a sleeping drive instead of spinning it up
			sm=$(smartctl -n standby -H -A "/dev/$dev" 2>/dev/null)
			if [[ $? -eq 2 ]] || grep -q 'STANDBY' <<<"$sm"; then
				health=standby
			else
				health=$(awk '/result:/{print $NF; exit} /SMART Health Status:/{print $NF; exit}' <<<"$sm")
				temp=$(awk '$1==194||$1==190{print $10; exit} /^Temperature:/{print $2; exit}' <<<"$sm")
				hours=$(awk '$1==9{print $10; exit} /^Power On Hours:/{gsub(/,/,"",$4); print $4; exit}' <<<"$sm")
			fi
		fi
		printf '  %-8s %-24s %8s %s%11s %11s%s %s%4d%%%s  %s %-5s %s%5s%s %7s\n' "$dev" "${model:--}" "$sz" \
			"$BCYN" "$(hr_rate $(((r1 - r0) / dt)))" "$(hr_rate $(((w1 - w0) / dt)))" "$RST" \
			"$(col "$busy" 50 90)" "$busy" "$RST" "$(dot "${health:-?}")" "${health:--}" \
			"$(col "${temp:-0}" 45 55)" "${temp:+${temp}°C}" "$RST" "${hours:+${hours}h}"
	done
	if $IS_ROOT && [[ -n $POOL ]] && mountpoint -q "$POOL"; then
		local errs scrub
		errs=$(btrfs device stats "$POOL" 2>/dev/null | awk '$2!=0{n+=$2} END{print n+0}')
		scrub=$(btrfs scrub status "$POOL" 2>/dev/null | awk -F': *' '/Scrub started/{s=$2} /Status/{st=$2} /Error summary/{e=$2} END{printf "%s, %s (%s)", st, s, e}')
		printf '  %spool%s %s  device errors: %s%s%s   last scrub: %s\n' "$DIM" "$RST" "$POOL" "$( ((errs > 0)) && echo "$RED" || echo "$GRN")" "$errs" "$RST" "${scrub:-never}"
	fi

	# services using disk / network / cpu right now
	hdr "TOP SERVICES" "(by combined share of disk, network, CPU and memory)"
	printf '  %s%-30s %6s %9s %11s %11s %11s %11s%s\n' "$DIM" service cpu mem+cache "disk read" "disk write" "net in" "net out" "$RST"
	local id c0 ior0 iow0 in0 out0 c1 m1 ior1 iow1 in1 out1 rows="" label
	for id in "${!U1[@]}"; do
		read -r c1 m1 ior1 iow1 in1 out1 <<<"${U1[$id]}"
		read -r c0 _ ior0 iow0 in0 out0 <<<"${U0[$id]:-$c1 $m1 $ior1 $iow1 $in1 $out1}"
		label=${id%.service}
		[[ -n ${CTR[$id]:-} ]] && label="ctr:${CTR[$id]}"
		[[ $label == docker-*.scope ]] && label="ctr:${label:7:12}"
		# label cpu% mem read/s write/s in/s out/s
		rows+="$label $(awk -v dt="$dt" -v nc="$ncpu" -v c="$((c1 - c0))" 'BEGIN{printf "%.1f", c/(dt*1e9)*100/nc}') $m1 $(((ior1 - ior0) / dt)) $(((iow1 - iow0) / dt)) $(((in1 - in0) / dt)) $(((out1 - out0) / dt))"$'\n'
	done
	local shown=0 cpu mem r w i o
	# Score = the unit's share of all disk traffic + share of all network
	# traffic + share of CPU + share of memory, so a service stands out whether
	# it is hammering one resource or using a bit of everything.
	while read -r _ label cpu mem r w i o; do
		[[ -z $label ]] && continue
		printf '  %-30s %s%5s%%%s %9s %s%11s %11s %11s %11s%s\n' "${label:0:30}" "$(col "${cpu%.*}" 50 80)" "$cpu" "$RST" "$(hb "$mem")" \
			"$BCYN" "$(hr_rate "$r")" "$(hr_rate "$w")" "$(hr_rate "$i")" "$(hr_rate "$o")" "$RST"
		shown=$((shown + 1))
	done < <(awk 'NF==7{l[NR]=$0; c[NR]=$2; m[NR]=$3; d[NR]=$4+$5; n[NR]=$6+$7; sc+=$2; sm+=$3; sd+=$4+$5; sn+=$6+$7}
      END{for (k in l) printf "%.6f %s\n", (sd?d[k]/sd:0)+(sn?n[k]/sn:0)+(sc?c[k]/sc:0)+(sm?m[k]/sm:0), l[k]}' <<<"$rows" |
		sort -rn | head -n "$TOP")
	((shown == 0)) && printf '  %snothing busy%s\n' "$DIM" "$RST"

	# scheduled jobs and failures
	if [[ -n $JOBS ]]; then
		hdr "JOBS" "(last run)"
		local j res when state
		for j in $JOBS; do
			state=$(systemctl show -p ActiveState --value "$j" 2>/dev/null)
			res=$(systemctl show -p Result --value "$j" 2>/dev/null)
			# e.g. "Mon 2026-10-05 22:04:16 EDT" -> "2026-10-05 22:04"
			when=$(systemctl show -p ExecMainExitTimestamp --value "$j" 2>/dev/null | awk 'NF{print $2, substr($3,1,5)}')
			if [[ $state == activating || $state == active ]]; then
				printf '  %s %-24s %srunning now%s\n' "$(dot running)" "${j%.service}" "$CYN" "$RST"
			else
				printf '  %s %-24s %s %s%s%s\n' "$(dot "$res")" "${j%.service}" "${res:-?}" "$DIM" "${when:-never run}" "$RST"
			fi
		done
	fi
	local failed
	failed=$(systemctl list-units --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd' ')
	if [[ -n $failed ]]; then
		printf '\n  %s● failed units:%s %s\n' "$RED" "$RST" "$failed"
	fi

	printf '\n'
	hr
	printf '  %srefresh %ss  │  sample %ss  │  %s  │  Ctrl+C to quit%s\n' "$DIM" "$REFRESH" "$SAMPLE" "$($IS_ROOT && echo 'running as root' || echo 'sudo adds SMART + scrub + container names')" "$RST"
}

# ── main ────────────────────────────────────────────────────────────────────

mapfile -t DISKS < <(physical_disks)
mapfile -t NICS < <(physical_nics)

cycle() {
	container_names
	snap D0 N0 U0 CPU0
	sleep "$SAMPLE"
	snap D1 N1 U1 CPU1
	local out
	out=$(render)
	if $ONCE; then
		printf '%s\n' "$out"
	else
		# draw over the previous frame instead of clearing (no flicker)
		tput cup 0 0 2>/dev/null || clear
		printf '%s\n' "$out"
		tput ed 2>/dev/null || true
	fi
}

if $ONCE; then
	cycle
	exit 0
fi

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null; exit 0' EXIT INT TERM
clear
while true; do
	cycle
	sleep $((REFRESH - SAMPLE))
done
