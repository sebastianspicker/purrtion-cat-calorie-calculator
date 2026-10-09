#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE="${1:-sync}"
if [ "$MODE" != sync ] && [ "$MODE" != --check ]; then echo "Usage: $0 [--check]" >&2; exit 2; fi
sync_one() {
  source="$ROOT/$1"; target="$ROOT/$2"
  if [ "$MODE" = --check ]; then
    if ! cmp -s "$source" "$target"; then echo "Shared data drift: $2. Run npm run sync:shared." >&2; exit 1; fi
  else
    mkdir -p "$(dirname "$target")"; cp "$source" "$target"
  fi
}
sync_one shared/default-plan.json packages/swift-core/Sources/PurrtionCore/Resources/default-plan.json
sync_one shared/golden-cases.json packages/swift-core/Tests/PurrtionCoreTests/Resources/golden-cases.json
