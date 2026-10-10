#!/usr/bin/env bash
# Check this machine against the Epic's minimum hardware and the Docker setup.
# Usage: scripts/lab-check.sh [A|B]     (profile to check against, default B)
# Exit code: 0 when Docker and Compose are usable (hardware shortfalls are
# warnings, because the lab runs "at whatever scale is actually available"),
# 1 when a hard requirement fails.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

profile="${1:-B}"
case "$profile" in
  A) min_cpu=8; min_ram_gb=32; min_disk_gb=200 ;;
  B) min_cpu=8; min_ram_gb=16; min_disk_gb=100 ;;
  *) die "profile must be A or B" ;;
esac

fail=0; warn=0
row() { printf '%-6s %-22s %s\n' "$1" "$2" "$3"; }
pass() { row PASS "$1" "$2"; }
warn() { row WARN "$1" "$2"; warn=$((warn + 1)); }
bad()  { row FAIL "$1" "$2"; fail=$((fail + 1)); }
info() { row INFO "$1" "$2"; }

echo "Lab check against Profile $profile (min ${min_cpu} CPU, ${min_ram_gb} GB RAM, ${min_disk_gb} GB free SSD)"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Machine ---------------------------------------------------------------
. /etc/os-release
info "OS" "$PRETTY_NAME, kernel $(uname -r)"
wsl=0; grep -qi microsoft /proc/version && wsl=1
[[ $wsl == 1 ]] && info "Host" "WSL2 VM: CPU, RAM and disk below are what WSL is allowed to use"

cpu_model=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
cpus=$(nproc)
if (( cpus >= min_cpu )); then pass "CPU" "$cpus logical CPUs ($cpu_model)"
else warn "CPU" "$cpus logical CPUs, profile wants $min_cpu cores ($cpu_model)"; fi

ram_gb=$(awk '/MemTotal/{printf "%.1f", $2/1048576}' /proc/meminfo)
swap_gb=$(awk '/SwapTotal/{printf "%.1f", $2/1048576}' /proc/meminfo)
if awk -v r="$ram_gb" -v m="$min_ram_gb" 'BEGIN{exit !(r >= m)}'; then pass "RAM" "${ram_gb} GB (+${swap_gb} GB swap)"
else warn "RAM" "${ram_gb} GB (+${swap_gb} GB swap), profile wants $min_ram_gb GB"; fi

data_fs=$(df -PT "$LAB_ROOT" | awk 'NR==2{print $2}')
disk_gb=$(df -P -BG "$LAB_ROOT" | awk 'NR==2{gsub("G","",$4); print $4}')
disk_note="on $(df -P "$LAB_ROOT" | awk 'NR==2{print $1}') ($data_fs)"
if [[ $wsl == 1 && -d /mnt/c ]]; then
  # The WSL ext4.vhdx grows on the Windows C: drive, so C:'s free space is the real limit.
  c_gb=$(df -P -BG /mnt/c | awk 'NR==2{gsub("G","",$4); print $4}')
  disk_note="$disk_note; virtual disk lives on Windows C:, which has ${c_gb} GB free"
  (( c_gb < disk_gb )) && disk_gb=$c_gb
fi
if (( disk_gb >= min_disk_gb )); then pass "Free disk" "${disk_gb} GB $disk_note"
else warn "Free disk" "${disk_gb} GB usable, profile wants $min_disk_gb GB ($disk_note)"; fi
[[ "$data_fs" == "ext4" || "$data_fs" == "xfs" ]] && pass "Filesystem" "$data_fs (Linux filesystem, not a /mnt/c Windows mount)" \
  || warn "Filesystem" "$data_fs: keep lab data on a Linux filesystem, not /mnt/c"

# --- Docker ----------------------------------------------------------------
if docker info >/dev/null 2>&1; then
  pass "Docker Engine" "$(docker version --format '{{.Server.Version}}') ($(docker info --format '{{.OperatingSystem}}'))"
  [[ "$(docker info --format '{{.CgroupVersion}}')" == "2" ]] && pass "cgroup" "v2 (Compose CPU and memory limits apply)" \
    || warn "cgroup" "not v2: Compose resource limits may not apply"
  info "Docker root" "$(docker info --format '{{.DockerRootDir}}') ($(docker info --format '{{.Driver}}'))"
else
  bad "Docker Engine" "not reachable: start Docker (sudo service docker start)"
fi

compose_ver=$(docker compose version --short 2>/dev/null || true)
if [[ "$compose_ver" =~ ^v?([0-9]+) ]] && (( BASH_REMATCH[1] >= 2 )); then pass "Compose" "v${compose_ver#v} (Compose v2+ plugin)"
else bad "Compose" "Compose v2+ plugin (docker compose) not found"; fi

if docker network inspect "$LAB_NETWORK" >/dev/null 2>&1; then pass "Network" "$LAB_NETWORK exists"
else info "Network" "$LAB_NETWORK not created yet (scripts/up.sh creates it)"; fi

for port in 9000 9001; do
  if ss -Hltn "sport = :$port" 2>/dev/null | grep -q .; then
    owner=$(docker ps --filter "publish=$port" --format '{{.Names}}' | head -1)
    info "Port $port" "in use${owner:+ by $owner}"
  else pass "Port $port" "free on 127.0.0.1"; fi
done

for tool in git gitleaks openssl; do
  path="$(command -v "$tool")" && pass "$tool" "${path/#$HOME/\~}" || warn "$tool" "not installed"
done

echo
echo "Result: $fail failure(s), $warn warning(s)"
(( fail == 0 ))
