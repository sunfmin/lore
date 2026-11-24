#!/bin/bash
# device-run.sh: build an iOS app signed on the host its iPhone is paired to (here, or a host SSH
# reaches), put it on the phone, copy files into its data container, then launch it or run its tests,
# and bring the result back. The steps are the skill run-on-a-device's; signing is apple-dev-signing's.
# A phone on another host gets this checkout's source sent there and built there; only small files
# leave this host, never model weights (download those on the phone's host and pass there:<path>).
#
# Credentials come from the environment: run it as
#   rolesmith env apple-dev-signing -- device-run.sh …
# APPLE_DEV_P12_B64, APPLE_DEV_P12_PASSWORD, ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_B64, and
# APPLE_DEV_TEAM (or --team).
#
# Usage:
#   device-run.sh --project <dir with project.yml or .xcodeproj> --scheme <scheme> [options] <action>
# Actions (one):
#   --build                   build only, on the phone's host; nothing reaches the phone
#   --install                 install only
#   --launch [seconds]        install, launch with the console attached for <seconds> (default 60);
#                             the app keeps running after
#   --test [target ...]       build-for-testing, run the tests on the phone (all, or -only-testing targets)
# Options:
#   --udid <udid>             the phone (default: the first physical, available, paired one found)
#   --host <ssh host>         the host the phone is paired to (default: here first, then ~/.ssh/config hosts)
#   --copy-in <src>=<dest>    copy <src> to <dest> in the app's data container, e.g.
#                             there:.cache/x/models="Library/Application Support/X/models". Repeatable.
#                             there:<path> is a path on the phone's host (relative to its home); nothing
#                             is sent. A plain <src> is on this host; with the phone on another host it
#                             travels by rsync and must be under 100 MB (weights: download them there).
#   --arg <arg>               a launch argument for --launch. Repeatable.
#   --configuration <name>    Debug (default) or Release; timings mean little in Debug. --test in Release
#                             builds with ENABLE_TESTABILITY=YES so @testable imports compile
#   --team <team id>          overrides APPLE_DEV_TEAM
#   --build-there             --project is a path on the phone's host (a checkout there), built as it is;
#                             nothing is sent. Without it, a phone on another host gets the git checkout
#                             holding --project (tracked and untracked, not ignored, files) mirrored to
#                             ~/.cache/device-run/src/<repo> there, and the build runs in that mirror.
#   --out <dir>               where the run's results land here (default ./.build/device-run)
# Exit: 0 when the action passed; 1 when it failed; 2 usage; 3 no phone found.

# The whole script is one { } block, so bash reads all of it before running any: a rolesmith update
# that rewrites this file mid-run does not change the run.
{
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 2; }
say() { printf 'device-run: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

project= scheme= config=Debug udid= host= build_there= action= launch_secs=60 team=${APPLE_DEV_TEAM:-} out=./.build/device-run
copies=() args=() tests=()
while [ $# -gt 0 ]; do
  case $1 in
    --project) project=$2; shift 2 ;;
    --scheme) scheme=$2; shift 2 ;;
    --configuration) config=$2; shift 2 ;;
    --udid) udid=$2; shift 2 ;;
    --host) host=$2; shift 2 ;;
    --copy-in) copies+=("$2"); shift 2 ;;
    --arg) args+=("$2"); shift 2 ;;
    --team) team=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --build-there) build_there=1; shift ;;
    --build) action=build; shift ;;
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
  [ -n "${!v:-}" ] || die "$v is not set: run under rolesmith env apple-dev-signing -- …"
done
mkdir -p "$out"; out=$(cd "$out" && pwd)
[ -n "$build_there" ] || project=$(cd "$project" && pwd)   # with --build-there it is a path on the phone's host

# ---- find the phone: here first, then the hosts SSH reaches --------------------------------------
phones_on() { # host ("" = here) -> lines "READY udid name model os" or "WAKE udid"
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
    if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
        continue
    if cp.get("pairingState") != "paired" or not dp.get("ddiServicesAvailable", False):
        why = "not paired" if cp.get("pairingState") != "paired" else "developer services off (locked or asleep: unlock it)"
        print(f"device-run: {dp.get('name', '?')} ({hw.get('udid')}) is there but not ready: {why}", file=sys.stderr)
        if cp.get("pairingState") == "paired":
            print("WAKE", hw.get("udid"))
        continue
    if True:
        print("READY", hw.get("udid"), dp.get("name", "?").replace(" ", "_"), hw.get("marketingName", "?").replace(" ", "_"), dp.get("osVersionNumber", "?"))
PY
  rm -f "$j"
}
pick() { # host [connect timeout] -> sets udid/phone if found
  local h=$1 ct=${2:-5} line wake="" try   # `set -- $line` below replaces $1 and $2
  for try in 1 2; do
    while read -r line; do
      set -- $line
      if [ "$1" = READY ] && { [ -z "$udid" ] || [ "$2" = "$udid" ]; }; then udid=$2; phone="$3 ($4, iOS $5)"; return 0; fi
      if [ "$1" = WAKE ] && { [ -z "$udid" ] || [ "$2" = "$udid" ]; }; then wake="$wake $2"; fi
    done < <(phones_on "$h" "$ct")
    [ -n "$wake" ] && [ "$try" = 1 ] || return 1
    # A paired phone over Wi-Fi drops its developer tunnel when idle; asking for its details brings it back.
    for u in $wake; do
      say "bringing up the developer connection to $u"
      local c="perl -e 'alarm shift; exec @ARGV' 45 xcrun devicectl device info details --device $u >/dev/null 2>&1"
      if [ -z "$h" ]; then bash -c "$c"; else ssh -o BatchMode=yes -o ConnectTimeout="$ct" "$h" "$c"; fi || true
    done
  done
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

q() { printf '%q' "$1"; }

# ---- sign and build: here, or (--build-there) on the phone's host ---------------------------------
# One script does both, so the signing steps are the same wherever the build runs. It reads the
# credentials from its environment, makes its own keychain and removes it on exit
# (apple-dev-signing's sign-for-development), and prints APP=<the built .app>.
build_script() {
  cat <<'BUILD'
set -euo pipefail
export PATH=/opt/homebrew/bin:$HOME/homebrew/bin:$PATH
umask 077
keys=$(mktemp -d "${TMPDIR:-/tmp}/device-run-keys.XXXXXX")
kc=$keys/run.keychain-db; kcpass=$(openssl rand -hex 24)
old_list=$(security list-keychains -d user | tr -d '"')
cleanup() {
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
security list-keychains -d user -s $old_list "$kc"
case $DD in /*) ;; *) DD=$PWD/$DD ;; esac   # relative to where the build starts, before the cd below
cd "${PROJ/#\~/$HOME}"
if [ -f project.yml ]; then xcodegen generate --quiet; fi
container=(-project "$(ls -d *.xcodeproj | head -1)"); ls -d *.xcworkspace >/dev/null 2>&1 && container=(-workspace "$(ls -d *.xcworkspace | head -1)")
mkdir -p "$DD"
only=(); for t in $ONLY; do only+=("-only-testing:$t"); done
build() { xcodebuild "${container[@]}" -scheme "$SCHEME" -configuration "$CONFIG" -destination "$DEST" -derivedDataPath "$DD" \
            ${only[@]+"${only[@]}"} ${TESTABLE:+ENABLE_TESTABILITY=YES} DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic OTHER_CODE_SIGN_FLAGS="--keychain $kc" \
            -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
            -authenticationKeyPath "$keys/asc.p8" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
            "$VERB" > "$DD/build.log" 2>&1; }
if ! build; then
  # A new phone's profile can land after the first build asks for it (sign-for-development).
  if grep -q 'mobileprovision' "$DD/build.log"; then echo "device-run: profile not there yet; building again" >&2; build
  else grep -E 'error:' "$DD/build.log" | sort -u | tail -20 >&2; echo "device-run: build failed: $DD/build.log" >&2; exit 1; fi
fi
# The app under test, not a UI test's <Target>-Runner.app, which sorts first when its name does (E2ETests-Runner before RollMind).
app=$(ls -d "$DD"/Build/Products/$CONFIG-iphoneos/*.app | grep -v -- '-Runner\.app$' | head -1 || true)
[ -n "$app" ] || { echo "device-run: no app in $DD/Build/Products/$CONFIG-iphoneos" >&2; exit 1; }
echo "APP=$app"
BUILD
}
verb=build; [ "$action" = test ] && verb=build-for-testing
testable=; [ "$action" = test ] && [ "$config" != Debug ] && testable=1
only_list=${tests[*]+"${tests[*]}"}
# The build runs where the phone is paired. A phone on another host gets the source, not the products:
# the checkout holding --project is mirrored there (what git tracks, plus untracked files it does not
# ignore; weights and build output are ignored), and --project becomes its path in the mirror.
# One mirror per repo (named from origin, so every worktree of it shares the mirror and the build's
# DerivedData), held under a lock from the send to the end of the build; a lock older than 30 min is
# a dead run's and is taken over.
source_sent= lock=
commit_of() { # checkout -> its short HEAD, +uncommitted when it has changes; nothing outside git
  local c; c=$(git -C "$1" rev-parse --short HEAD 2>/dev/null) || return 0
  [ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ] || c="$c+uncommitted"
  echo "$c"
}
unlock() { [ -z "$lock" ] || ssh -o BatchMode=yes "$host" "rmdir $(q "$lock")" 2>/dev/null || true; lock=; }
send_source() {
  local root rel name dir filter s
  root=$(git -C "$project" rev-parse --show-toplevel 2>/dev/null) \
    || die "--project $project is in no git checkout: pass --build-there with a checkout's path on $host"
  rel=${project#"$root"}; rel=${rel#/}
  name=$(basename "$(git -C "$root" remote get-url origin 2>/dev/null || echo "$root")" .git)
  dir=.cache/device-run/src/$name
  s=$(date +%s)
  until ssh -o BatchMode=yes "$host" "mkdir -p .cache/device-run/src; find $(q "$dir.lock") -maxdepth 0 -mmin +30 -exec rmdir {} \; 2>/dev/null; mkdir $(q "$dir.lock") 2>/dev/null"; do
    [ $(( $(date +%s) - s )) -lt 1800 ] || die "$host:$dir.lock held for 30 min by another build"
    say "another build of $name is running on $host; waiting"; sleep 15
  done
  lock=$dir.lock; trap unlock EXIT
  filter=$(mktemp)
  # One include rule per file and per directory above it, then exclude the rest; --delete-excluded
  # makes the mirror exactly that list, so a file deleted here is gone there too.
  (cd "$root" && git ls-files -co --exclude-standard) | awk '
    { gsub(/[[*?\\]/, "\\\\&"); n = split($0, p, "/"); d = ""
      for (i = 1; i < n; i++) { d = d "/" p[i]; if (!(d in seen)) { seen[d] = 1; print "+ " d "/" } }
      print "+ /" $0 }
    END { print "- *" }' > "$filter"
  ssh -o BatchMode=yes "$host" "mkdir -p $(q "$dir")"
  s=$(date +%s)
  rsync -a --delete --delete-excluded --filter=". $filter" "$root/" "$host:$dir/" || { rm -f "$filter"; die "sending the source to $host failed"; }
  rm -f "$filter"
  source_sent=$(commit_of "$root")
  say "source $source_sent sent to $host:$dir in $(( $(date +%s) - s ))s"
  project=$dir${rel:+/$rel}
  dd_there=.cache/device-run/build/$name/DerivedData
}
there=; [ -n "$host" ] && there=1
dest="id=$udid"
if [ -n "$there" ]; then
  dd_there=.cache/device-run/$scheme/DerivedData
  [ -n "$build_there" ] || send_source   # sets dd_there to the mirror's own
else
  dd_there=$out/DerivedData
  source_sent=$(commit_of "$project")
fi
envs=$(printf 'export APPLE_DEV_P12_B64=%q APPLE_DEV_P12_PASSWORD=%q ASC_KEY_ID=%q ASC_ISSUER_ID=%q ASC_PRIVATE_KEY_B64=%q TEAM=%q PROJ=%q SCHEME=%q DEST=%q VERB=%q ONLY=%q DD=%q CONFIG=%q TESTABLE=%q\n' \
  "$APPLE_DEV_P12_B64" "$APPLE_DEV_P12_PASSWORD" "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_PRIVATE_KEY_B64" "$team" "$project" "$scheme" "$dest" "$verb" "$only_list" "$dd_there" "$config" "$testable")
s=$(date +%s)
# The credentials travel on stdin, never in a command line another user could read.
if [ -n "$there" ]; then built=$( { echo "$envs"; build_script; } | ssh -o BatchMode=yes "$host" 'bash -s') || die "build on $host failed"
else built=$( { echo "$envs"; build_script; } | bash -s) || die "build failed: $dd_there/build.log"; fi
app=${built##*APP=}
unlock
say "built in $(( $(date +%s) - s ))s${there:+ on $host}"
products=$(dirname "$(dirname "$app")")   # .../Build/Products
if [ "$action" = build ]; then
  printf '{"phone":"%s","udid":"%s","host":"%s","app":"%s","action":"build","source":"%s","status":0}\n' \
    "$phone" "$udid" "${host:-$(hostname -s)}" "$app" "${source_sent:-}" | tee "$out/run.json"
  exit 0
fi
if [ -n "$there" ]; then
  bundle=$(ssh -o BatchMode=yes "$host" "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' $(q "$app/Info.plist")")
  remote=.cache/device-run/$bundle; rapp=$app; rproducts=$products
  ssh -o BatchMode=yes "$host" "mkdir -p $remote/in"
else
  bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
  remote=; rapp=$app; rproducts=$products
fi

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
  src=${c%%=*}; dst=${c#*=}
  if [ "${src#there:}" != "$src" ]; then   # already on the phone's host: copy from there, send nothing
    rsrc=${src#there:}; rsrc=${rsrc#\~/}; src=$rsrc   # commands there start in its home
  else
  src=${src/#\~/$HOME}
  [ -e "$src" ] || die "--copy-in: $src does not exist"
  if [ -n "$host" ]; then
    kb=$(du -sk "$src" | cut -f1)
    [ "$kb" -lt 102400 ] || die "--copy-in: $src is $(( kb / 1024 )) MB, too much to send from this host: download it on $host (models from Hugging Face) and pass there:<path>"
    # Under $HOME it lands at the same path on the phone's host, so a copy made there by hand is reused.
    case $src in "$HOME"/*) rdir=$(dirname "${src#"$HOME"/}") ;; *) rdir=$remote/in/$i ;; esac
    ssh -o BatchMode=yes "$host" "mkdir -p $(q "$rdir")"
    s=$(date +%s); rsync -a "$src" "$host:$rdir/"; rsrc=$rdir/$(basename "$src")
    say "$(basename "$src") on $host in $(( $(date +%s) - s ))s"
  else rsrc=$src; fi
  fi
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
    [ -z "$a" ] || a=" --$a"   # after --, devicectl reads no app argument (e.g. -caption-bench) as its own option
    # The console detaches after launch_secs and the app keeps running. devicectl forwards the signals
    # it can catch to the app (an alarm's SIGALRM killed it: "App terminated due to signal 14"), so it
    # is stopped with SIGKILL, which it cannot forward.
    run_detached "xcrun devicectl device process launch --device $udid --console --terminate-existing $bundle$a & p=\$!; i=0; while [ \$i -lt $launch_secs ] && kill -0 \$p 2>/dev/null; do sleep 1; i=\$((i+1)); done; kill -9 \$p 2>/dev/null; wait \$p; true" \
      $(( launch_secs + 120 )) || status=$?
    say "console: $out/run.log" ;;
  test)
    xrp=$(on "ls $(q "$rproducts")/*.xctestrun | head -1")
    bundle_dir="$J/result.xcresult"
    # The .xctestrun lists every test of the scheme: -only-testing given at build-for-testing does not narrow the run.
    only=""; for t in ${tests[@]+"${tests[@]}"}; do only="$only -only-testing:$(q "$t")"; done
    run_detached "rm -rf $bundle_dir; xcodebuild test-without-building -xctestrun $(q "$xrp") -destination id=$udid$only -resultBundlePath $bundle_dir" 3600 || status=$?
    on "xcrun xcresulttool get test-results summary --path $bundle_dir --compact" > "$out/summary.json" || true
    on "rm -rf $J/attachments && xcrun xcresulttool export attachments --path $bundle_dir --output-path $J/attachments >/dev/null" || true
    if [ -n "$host" ]; then rsync -a --delete "$host:.cache/device-run/$bundle/attachments/" "$out/attachments/" || true
    else rm -rf "$out/attachments"; cp -R ~/.cache/device-run/"$bundle"/attachments "$out/attachments" 2>/dev/null || true; fi
    say "summary: $out/summary.json, attachments: $out/attachments" ;;
esac
printf '{"phone":"%s","udid":"%s","host":"%s","bundle":"%s","action":"%s","source":"%s","status":%d}\n' \
  "$phone" "$udid" "${host:-$(hostname -s)}" "$bundle" "$action" "${source_sent:-}" "$status" | tee "$out/run.json"
exit $(( status == 0 ? 0 : 1 ))
}
