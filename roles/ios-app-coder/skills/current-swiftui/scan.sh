#!/bin/sh
# Prints each use of an API the skill current-swiftui replaces, as file:line: text.
# Usage: scan.sh <dir or file>...   Exits 1 when anything was found.
[ "$#" -gt 0 ] || { echo "usage: scan.sh <dir or file>..." >&2; exit 2; }
grep -rnE --include='*.swift' \
  -e '\bNavigationView\b' -e '\.foregroundColor\(' -e '\.cornerRadius\(' -e '\.tabItem *\{' \
  -e '\bObservableObject\b' -e '@Published\b' -e '@StateObject\b' -e '@ObservedObject\b' \
  -e '\bPreviewProvider\b' -e 'Task\.sleep\(nanoseconds:' -e 'UIScreen\.main' -e '\bAnyView\b' \
  -e 'DispatchQueue\.main' -e 'onChange\(of:[^)]*\) *\{ *[A-Za-z_]+ +in' "$@" && exit 1
exit 0
