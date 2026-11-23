#!/bin/bash
# device-run.sh: build an iOS app signed on this host, put it on a real iPhone (paired here, or to a
# host SSH reaches), copy files into its data container, then launch it or run its tests, and bring
# the result back. The steps are the skill run-on-a-device's; signing is apple-dev-signing's.
#
# Credentials come from the environment: run it as
#   (eval "$(mytokens env apple-dev-signing)"; device-run.sh …)
# APPLE_DEV_P12_B64, APPLE_DEV_P12_PASSWORD, ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_B64, and
# APPLE_DEV_TEAM (or --team).
#
# Usage:
#   device-run.sh --project <dir with project.yml or .xcodeproj> --scheme <scheme> [options] <action>
# Actions (one):
#   --install                 install only
#   --launch [seconds]        install, launch with the console attached for <seconds> (default 60)
#   --test [target ...]       build-for-testing, run the tests on the phone (all, or -only-testing targets)
# Options:
#   --udid <udid>             the phone (default: the first physical, available, paired one found)
#   --host <ssh host>         the host the phone is paired to (default: here first, then ~/.ssh/config hosts)
#   --copy-in <src>=<dest>    copy <src> (a file or directory on this host) to <dest> in the app's
#                             data container, e.g. ~/.cache/x/models="Library/Application Support/X/models".
#                             Repeatable. Only changed files travel (rsync, then devicectl copy to).
#   --arg <arg>               a launch argument for --launch. Repeatable.
#   --team <team id>          overrides APPLE_DEV_TEAM
#   --out <dir>               where the run's results land here (default ./.build/device-run)
# Exit: 0 when the action passed; 1 when it failed; 2 usage; 3 no phone found.
set -euo pipefail

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
say() { printf 'device-run: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

project= scheme= udid= host= action= launch_secs=60 team=${APPLE_DEV_TEAM:-} out=./.build/device-run
copies=() args=() tests=()
while [ $# -gt 0 ]; do
  case $1 in
    --project) project=$2; shift 2 ;;
    --scheme) scheme=$2; shift 2 ;;
    --udid) udid=$2; shift 2 ;;
    --host) host=$2; shift 2 ;;
    --copy-in) copies+=("$2"); shift 2 ;;
    --arg) args+=("$2"); shift 2 ;;
    --team) team=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --install) action=install; shift ;;
    --launch) action=launch; shift; case ${1:-} in ''|-*) ;; *) launch_secs=$1; shift ;; esac ;;
    --test) action=test; shift; while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do tests+=("$1"); shift; done ;;
    -h|--help) usage ;;
    *) say "unknown argument: $1"; usage ;;
  esac
done
[ -n "$project" ] && [ -n "$scheme" ] && [ -n "$action" ] || usage
[ -n "$team" ] || die "no team: set APPLE_DEV_TEAM or pass --team"
for v in APPLE_DEV_P12_B64 APPLE_DEV_P12_PASSWORD ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_B64; do
  [ -n "${!v:-}" ] || die "$v is not set: run under (eval \"\$(mytokens env apple-dev-signing)\"; …)"
done
mkdir -p "$out"; out=$(cd "$out" && pwd)
project=$(cd "$project" && pwd)

# ---- find the phone: here first, then the hosts SSH reaches --------------------------------------
phones_on() { # host ("" = here) -> lines "udid name model os"
  local j; j=$(mktemp)
  if [ -z "$1" ]; then xcrun devicectl list devices --json-output "$j" >/dev/null 2>&1 || true
  else ssh -o BatchMode=yes -o ConnectTimeout="${2:-5}" "$1" 'f=$(mktemp); xcrun devicectl list devices --json-output "$f" >/dev/null 2>&1; cat "$f"; rm -f "$f"' > "$j" 2>/dev/null || true; fi
  /usr/bin/plutil -convert json -o - "$j" >/dev/null 2>&1 || { rm -f "$j"; return 0; }
  /usr/bin/python3 - "$j" <<'PY'
import json, sys
try: devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception: sys.exit(0)
for d in devices:
    hw, dp, cp = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("platform") == "iOS" and cp.get("pairingState") == "paired" \
       and dp.get("ddiServicesAvailable", False):
        print(hw.get("udid"), dp.get("name", "?").replace(" ", "_"), hw.get("marketingName", "?").replace(" ", "_"), dp.get("osVersionNumber", "?"))
PY
  rm -f "$j"
}
pick() { # host -> sets udid/phone if found
  local line
  while read -r line; do
    set -- $line
    if [ -z "$udid" ] || [ "$1" = "$udid" ]; then udid=$1; phone="$2 ($3, iOS $4)"; return 0; fi
  done < <(phones_on "$1" "${2:-}")
  return 1
}
phone=
# A named host is waited for (30 s to connect); a scanned one is not (5 s).
if [ -n "$host" ]; then pick "$host" 30 || { say "no available phone${udid:+ $udid} on $host"; exit 3; }
elif pick ""; then host=
else
  for h in $(awk 'tolower($1)=="host"{for(i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null); do
    pick "$h" && { host=$h; break; }
  done
  [ -n "$phone" ] || { say "no available phone${udid:+ $udid} here or on: $(awk 'tolower($1)=="host"{print $2}' ~/.ssh/config 2>/dev/null | tr '\n' ' ')"; exit 3; }
fi
say "phone: $phone, udid $udid, paired to ${host:-this host}"
on() { if [ -z "$host" ]; then bash -c "$1"; else ssh -o BatchMode=yes "$host" "$1"; fi; }

# ---- the run's own keychain (apple-dev-signing's sign-for-development) ---------------------------
umask 077
keys=$(mktemp -d "${TMPDIR:-/tmp}/device-run-keys.XXXXXX")
kc=$keys/run.keychain-db; kcpass=$(openssl rand -hex 24)
old_list=$(security list-keychains -d user | tr -d '"')
cleanup() {
  # shellcheck disable=SC2086
  security list-keychains -d user -s $old_list >/dev/null 2>&1 || true
  security delete-keychain "$kc" >/dev/null 2>&1 || true
  rm -rf "$keys"
}
trap cleanup EXIT
printf %s "$APPLE_DEV_P12_B64" | base64 -d > "$keys/dev.p12"
printf %s "$ASC_PRIVATE_KEY_B64" | base64 -d > "$keys/asc.p8"
security create-keychain -p "$kcpass" "$kc"
security set-keychain-settings "$kc"
security unlock-keychain -p "$kcpass" "$kc"
security import "$keys/dev.p12" -k "$kc" -f pkcs12 -P "$APPLE_DEV_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kcpass" "$kc" >/dev/null 2>&1
rm -f "$keys/dev.p12"
# shellcheck disable=SC2086
security list-keychains -d user -s $old_list "$kc"
sign=(DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic OTHER_CODE_SIGN_FLAGS="--keychain $kc"
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration
      -authenticationKeyPath "$keys/asc.p8" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

# ---- build here -----------------------------------------------------------------------------------
cd "$project"
if [ -f project.yml ]; then xcodegen generate --quiet; fi
container=(-project "$(ls -d *.xcodeproj | head -1)"); ls -d *.xcworkspace >/dev/null 2>&1 && container=(-workspace "$(ls -d *.xcworkspace | head -1)")
dd=$out/DerivedData
dest=(-destination "id=$udid"); [ -n "$host" ] && dest=(-destination 'generic/platform=iOS')
verb=build; [ "$action" = test ] && verb=build-for-testing
only=(); for t in ${tests[@]+"${tests[@]}"}; do only+=("-only-testing:$t"); done
build() { xcodebuild "${container[@]}" -scheme "$scheme" -configuration Debug "${dest[@]}" -derivedDataPath "$dd" \
            ${only[@]+"${only[@]}"} "${sign[@]}" "$verb" > "$out/build.log" 2>&1; }
s=$(date +%s)
if ! build; then
  # A new phone's profile can land after the first build asks for it (sign-for-development).
  grep -q 'mobileprovision' "$out/build.log" && { say "profile not there yet; building again"; build; } \
    || { grep -E 'error:' "$out/build.log" | sort -u | tail -20 >&2; die "build failed: $out/build.log"; }
fi
say "built in $(( $(date +%s) - s ))s"
products=$dd/Build/Products
app=$(ls -d "$products"/Debug-iphoneos/*.app | head -1)
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")

# ---- the products and copy-ins reach the phone's host ---------------------------------------------
if [ -n "$host" ]; then
  remote=.cache/device-run/$bundle
  ssh -o BatchMode=yes "$host" "mkdir -p $remote/products $remote/in"
  rsync -a --delete "$products/" "$host:$remote/products/"
  rapp=$remote/products/Debug-iphoneos/$(basename "$app")
else
  remote=; rapp=$app
fi
q() { printf '%q' "$1"; }

# ---- install, then copy into the app's data container ---------------------------------------------
if [ "$action" != test ]; then
  on "xcrun devicectl device install app --device $udid $(q "$rapp") >/dev/null" || die "install failed"
  say "installed $bundle"
fi
# A test run installs the app itself, later; the container must exist before anything is copied in.
if [ "$action" = test ] && [ ${#copies[@]} -gt 0 ]; then
  on "xcrun devicectl device install app --device $udid $(q "$rapp") >/dev/null" || die "install failed"
fi
i=0
for c in ${copies[@]+"${copies[@]}"}; do
  src=${c%%=*}; dst=${c#*=}; src=${src/#\~/$HOME}
  [ -e "$src" ] || die "--copy-in: $src does not exist"
  if [ -n "$host" ]; then
    # Under $HOME it lands at the same path on the phone's host, so a copy made there by hand is reused.
    case $src in "$HOME"/*) rdir=$(dirname "${src#"$HOME"/}") ;; *) rdir=$remote/in/$i ;; esac
    ssh -o BatchMode=yes "$host" "mkdir -p $(q "$rdir")"
    s=$(date +%s); rsync -a "$src" "$host:$rdir/"; rsrc=$rdir/$(basename "$src")
    say "$(basename "$src") on $host in $(( $(date +%s) - s ))s"
  else rsrc=$src; fi
  s=$(date +%s)
  on "xcrun devicectl device copy to --device $udid --domain-type appDataContainer --domain-identifier $bundle \
      --source $(q "$rsrc") --destination $(q "$dst") >/dev/null" || die "copy-in failed: $c"
  say "copied $(basename "$src") to $dst in $(( $(date +%s) - s ))s"
  i=$((i + 1))
done

# ---- run, detached on the phone's host so a dropped SSH does not end it ---------------------------
J="\$HOME/.cache/device-run/$bundle"   # expanded by the shell on the phone's host
run_detached() { # command, bound in seconds -> its output in $out/run.log, its status returned
  local job="$J/job" bound=$2
  on "mkdir -p $job && rm -f $job/done && cd ~ && (nohup bash -c $(q "$1; echo \$? > \"$job/done\"") > $job/log 2>&1 &)"
  local s; s=$(date +%s)
  until on "test -f $job/done"; do
    [ $(( $(date +%s) - s )) -lt "$bound" ] || { on "cat $job/log" > "$out/run.log" || true; die "no end after ${bound}s"; }
    sleep 10
  done
  on "cat $job/log" > "$out/run.log"
  return "$(on "cat $job/done")"
}
status=0
case $action in
  install) ;;
  launch)
    a=""; for x in ${args[@]+"${args[@]}"}; do a="$a $(q "$x")"; done
    run_detached "perl -e 'alarm shift; exec @ARGV' $launch_secs xcrun devicectl device process launch --device $udid --console --terminate-existing $bundle$a; true" \
      $(( launch_secs + 120 )) || status=$?
    say "console: $out/run.log" ;;
  test)
    xr=$(cd "$products" && ls *.xctestrun | head -1)
    bundle_dir="$J/result.xcresult"
    [ -n "$host" ] && xrp=$remote/products/$xr || xrp=$products/$xr
    run_detached "rm -rf $bundle_dir; xcodebuild test-without-building -xctestrun $(q "$xrp") -destination id=$udid -resultBundlePath $bundle_dir" 3600 || status=$?
    on "xcrun xcresulttool get test-results summary --path $bundle_dir --compact" > "$out/summary.json" || true
    on "rm -rf $J/attachments && xcrun xcresulttool export attachments --path $bundle_dir --output-path $J/attachments >/dev/null" || true
    if [ -n "$host" ]; then rsync -a --delete "$host:.cache/device-run/$bundle/attachments/" "$out/attachments/" || true
    else rm -rf "$out/attachments"; cp -R ~/.cache/device-run/"$bundle"/attachments "$out/attachments" 2>/dev/null || true; fi
    say "summary: $out/summary.json, attachments: $out/attachments" ;;
esac
printf '{"phone":"%s","udid":"%s","host":"%s","bundle":"%s","action":"%s","status":%d}\n' \
  "$phone" "$udid" "${host:-$(hostname -s)}" "$bundle" "$action" "$status" | tee "$out/run.json"
exit $(( status == 0 ? 0 : 1 ))
