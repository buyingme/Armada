#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# generate_baseline_fixtures.sh - Safely generate and promote replay baselines.
#
# This developer-only helper creates candidates from an existing replay. It does
# not record, rewrite, normalize, or convert the replay. The existing
# run_baseline_traces.sh verifier remains authoritative after installation.
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURE_DIR="$PROJECT_DIR/tests/fixtures/baseline_traces"
VERIFIER="$SCRIPT_DIR/run_baseline_traces.sh"
GAME_REPLAY_SOURCE="$PROJECT_DIR/src/core/commands/game_replay.gd"
BASELINE_TRACE_SOURCE="$PROJECT_DIR/src/autoload/baseline_trace.gd"
NETWORK_PORT=7350

MODE=""
SOURCE_REPLAY=""
INSTALL=false
REPLACE_EXISTING=false
GODOT=""
TMP_DIR=""
SOURCE_HASH=""
CURRENT_REPLAY_FORMAT=""
CURRENT_TRACE_FORMAT=""

PIDS=()
CANDIDATES=()
DESTINATIONS=()
INSTALL_EXISTED=()
INSTALL_BACKUPS=()
INSTALL_CHANGED=()
STAGING_FILES=()
INSTALL_ACTIVE=false


usage() {
    cat <<'EOF'
Usage:
  ./scripts/generate_baseline_fixtures.sh \
      --mode hot-seat --replay /absolute/path/to/replay.json \
      [--install] [--replace-existing]

  ./scripts/generate_baseline_fixtures.sh \
      --mode network --replay /absolute/path/to/replay.json \
      [--install] [--replace-existing]

Modes:
  hot-seat  Generate a replay, trace, and state-hash candidate.
  network   Run one host and client from one replay; only the replay can be
            installed because network traces and hashes are diagnostic.

Installation:
  By default all candidates are temporary and the repository is unchanged.
  --install installs only absent or byte-identical canonical fixtures.
  --install --replace-existing explicitly permits replacement of differing
  mode-specific fixtures. Verification failure restores the previous files.

There is intentionally no --all generation mode.
EOF
}


fail() {
    echo "ERROR: $*" >&2
    return 1
}


parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                [[ $# -ge 2 ]] || fail "--mode requires a value."
                MODE="$2"
                shift 2
                ;;
            --replay)
                [[ $# -ge 2 ]] || fail "--replay requires a value."
                SOURCE_REPLAY="$2"
                shift 2
                ;;
            --install)
                INSTALL=true
                shift
                ;;
            --replace-existing)
                REPLACE_EXISTING=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --all)
                fail "--all is not supported. Generate one mode at a time."
                ;;
            *)
                fail "Unknown option: $1"
                ;;
        esac
    done

    case "$MODE" in
        hot-seat|network) ;;
        "") fail "--mode is required." ;;
        *) fail "Unsupported mode '$MODE'. Use hot-seat or network." ;;
    esac
    [[ -n "$SOURCE_REPLAY" ]] || fail "--replay is required."
    [[ "$SOURCE_REPLAY" == /* ]] || fail "--replay must be an absolute path."
    if $REPLACE_EXISTING && ! $INSTALL; then
        fail "--replace-existing requires --install."
    fi
}


extract_format_constant() {
    local source_file="$1"
    awk '$1 == "const" && $2 == "FORMAT_VERSION:" && $3 == "int" \
            && $4 == "=" {print $5; exit}' "$source_file"
}


resolve_repository_formats() {
    CURRENT_REPLAY_FORMAT="$(extract_format_constant "$GAME_REPLAY_SOURCE")"
    CURRENT_TRACE_FORMAT="$(extract_format_constant "$BASELINE_TRACE_SOURCE")"
    [[ "$CURRENT_REPLAY_FORMAT" =~ ^[0-9]+$ ]] \
        || fail "Could not determine GameReplay.FORMAT_VERSION."
    [[ "$CURRENT_TRACE_FORMAT" =~ ^[0-9]+$ ]] \
        || fail "Could not determine BaselineTrace.FORMAT_VERSION."
}


require_tools() {
    command -v jq >/dev/null 2>&1 || fail "jq is required."
    command -v cmp >/dev/null 2>&1 || fail "cmp is required."
    command -v awk >/dev/null 2>&1 || fail "awk is required."
    if ! command -v shasum >/dev/null 2>&1 \
            && ! command -v sha256sum >/dev/null 2>&1; then
        fail "shasum or sha256sum is required."
    fi
    [[ -x "$VERIFIER" ]] || fail "Verifier is missing or not executable: $VERIFIER"
}


hash_file() {
    local file_path="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
    else
        sha256sum "$file_path" | awk '{print $1}'
    fi
}


decimal_fits_int64() {
    local encoded="$1"
    local digits="$encoded"
    local limit="9223372036854775807"
    if [[ "$encoded" == -* ]]; then
        digits="${encoded#-}"
        limit="9223372036854775808"
    fi
    if [[ ${#digits} -lt ${#limit} ]]; then
        return 0
    fi
    if [[ ${#digits} -gt ${#limit} ]]; then
        return 1
    fi
    local index
    for ((index = 0; index < ${#digits}; index++)); do
        local digit="${digits:index:1}"
        local limit_digit="${limit:index:1}"
        if ((10#$digit < 10#$limit_digit)); then
            return 0
        fi
        if ((10#$digit > 10#$limit_digit)); then
            return 1
        fi
    done
    return 0
}


validate_replay_preflight() {
    [[ -f "$SOURCE_REPLAY" ]] || fail "Replay does not exist: $SOURCE_REPLAY"
    [[ -r "$SOURCE_REPLAY" ]] || fail "Replay is not readable: $SOURCE_REPLAY"
    jq -e . "$SOURCE_REPLAY" >/dev/null 2>&1 \
        || fail "Replay is not valid JSON: $SOURCE_REPLAY"

    jq -e --argjson expected_format "$CURRENT_REPLAY_FORMAT" '
        (.header | type) == "object"
        and (.commands | type) == "array"
        and (.commands | length) > 0
        and (.header.format_version | type) == "number"
        and .header.format_version == $expected_format
        and (.header.initial_command_sequence | type) == "number"
        and .header.initial_command_sequence >= 0
        and (.header.initial_command_sequence
                == (.header.initial_command_sequence | floor))
        and (.header.rng_seed | type) == "string"
        and (.header.rng_seed | test("^-?(0|[1-9][0-9]*)$"))
    ' "$SOURCE_REPLAY" >/dev/null || fail \
        "Replay header/schema does not match current format $CURRENT_REPLAY_FORMAT."

    local rng_seed
    rng_seed="$(jq -r '.header.rng_seed' "$SOURCE_REPLAY")"
    [[ "$rng_seed" != "-0" ]] \
        || fail "Replay RNG seed is not in canonical decimal form."
    decimal_fits_int64 "$rng_seed" \
        || fail "Replay RNG seed is outside the signed 64-bit range."

    jq -e '
        .header.initial_command_sequence as $start
        | .commands as $commands
        | all(range(0; ($commands | length));
            . as $index
            | ($commands[$index] | type) == "object"
            and ($commands[$index].sequence | type) == "number"
            and ($commands[$index].sequence
                    == ($commands[$index].sequence | floor))
            and ($commands[$index].sequence == ($start + $index)))
    ' "$SOURCE_REPLAY" >/dev/null \
        || fail "Replay command sequences are missing, non-integral, or non-contiguous."

    SOURCE_HASH="$(hash_file "$SOURCE_REPLAY")"
    echo "Preflight passed."
    echo "  mode:          $MODE"
    echo "  replay format: $CURRENT_REPLAY_FORMAT"
    echo "  trace format:  $CURRENT_TRACE_FORMAT"
    echo "  source hash:   $SOURCE_HASH"
}


find_godot() {
    GODOT="${GODOT_BIN:-}"
    if [[ -n "$GODOT" ]]; then
        if [[ "$GODOT" == */* ]]; then
            [[ -x "$GODOT" ]] || fail "GODOT_BIN is not executable: $GODOT"
        else
            command -v "$GODOT" >/dev/null 2>&1 \
                || fail "GODOT_BIN is not on PATH: $GODOT"
        fi
        return
    fi
    if command -v godot >/dev/null 2>&1; then
        GODOT="godot"
    elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
        GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
    else
        fail "Godot binary not found. Set GODOT_BIN or add godot to PATH."
    fi
}


prepare_temp_dir() {
    TMP_DIR="$(mktemp -d -t armada_baseline_generate_XXXXXX)"
    [[ -d "$TMP_DIR" ]] || fail "Could not create temporary directory."
}


copy_replay_candidate() {
    local destination="$1"
    cp -- "$SOURCE_REPLAY" "$destination"
    local candidate_hash
    candidate_hash="$(hash_file "$destination")"
    [[ "$candidate_hash" == "$SOURCE_HASH" ]] \
        || fail "Replay candidate differs from the source replay."
}


validate_hash_file() {
    local hash_path="$1"
    [[ -s "$hash_path" ]] || fail "Missing state hash: $hash_path"
    [[ "$(wc -l < "$hash_path" | tr -d '[:space:]')" == "1" ]] \
        || fail "State hash must contain exactly one line: $hash_path"
    grep -Eq '^[0-9a-f]{64}$' "$hash_path" \
        || fail "State hash is not a lowercase SHA-256 digest: $hash_path"
}


validate_trace_header() {
    local trace_path="$1"
    local expected_mode="$2"
    local expected_role="$3"
    [[ -s "$trace_path" ]] || fail "Missing baseline trace: $trace_path"
    jq -s -e --argjson format "$CURRENT_TRACE_FORMAT" \
            --arg mode "$expected_mode" --arg role "$expected_role" '
        length > 1
        and .[0]._header == true
        and .[0].format_version == $format
        and .[0].mode == $mode
        and .[0].role == $role
    ' "$trace_path" >/dev/null \
        || fail "Trace header does not match $expected_mode/$expected_role."
}


validate_hot_seat_trace_matches_replay() {
    local replay_path="$1"
    local trace_path="$2"
    jq -n -e --slurpfile replay "$replay_path" \
            --slurpfile trace "$trace_path" '
        ($replay | length) == 1
        and (($replay[0].commands | length) == ($trace[1:] | length))
        and (($replay[0].commands
                | map({seq: .sequence, command_type: .type}))
            == ($trace[1:]
                | map({seq: .seq, command_type: .command_type})))
    ' >/dev/null || fail \
        "Hot-seat trace command identities do not match the replay."
}


generate_hot_seat_candidates() {
    local replay_candidate="$TMP_DIR/replay_hot_seat_solo.json"
    local trace_candidate="$TMP_DIR/baseline_trace_hot_seat_solo.jsonl"
    local generated_hash="${trace_candidate}.state_hash"
    local hash_candidate="$TMP_DIR/baseline_state_hash_hot_seat_solo.txt"
    local replay_log="$TMP_DIR/hot_seat.log"

    copy_replay_candidate "$replay_candidate"
    echo "Generating hot-seat candidates..."
    if ! "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --replay "$replay_candidate" \
            --baseline-output "$trace_candidate" \
            >"$replay_log" 2>&1; then
        echo "Hot-seat replay failed:" >&2
        tail -60 "$replay_log" >&2
        return 1
    fi
    [[ -f "$generated_hash" ]] \
        || fail "Hot-seat replay did not produce a state hash."
    mv -- "$generated_hash" "$hash_candidate"

    validate_trace_header "$trace_candidate" "hot_seat" "solo"
    validate_hot_seat_trace_matches_replay "$replay_candidate" "$trace_candidate"
    validate_hash_file "$hash_candidate"

    CANDIDATES=("$replay_candidate" "$trace_candidate" "$hash_candidate")
    DESTINATIONS=(
        "$FIXTURE_DIR/replay_hot_seat_solo.json"
        "$FIXTURE_DIR/baseline_trace_hot_seat_solo.jsonl"
        "$FIXTURE_DIR/baseline_state_hash_hot_seat_solo.txt"
    )
}


generate_network_candidates() {
    local replay_candidate="$TMP_DIR/replay_network.json"
    local host_trace="$TMP_DIR/network_host.jsonl"
    local client_trace="$TMP_DIR/network_client.jsonl"
    local host_log="$TMP_DIR/network_host.log"
    local client_log="$TMP_DIR/network_client.log"

    copy_replay_candidate "$replay_candidate"
    echo "Generating network diagnostics..."
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --server --port "$NETWORK_PORT" \
            --replay "$replay_candidate" \
            --baseline-output "$host_trace" \
            >"$host_log" 2>&1 &
    local host_pid=$!
    PIDS+=("$host_pid")
    sleep 2
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --connect "127.0.0.1:$NETWORK_PORT" \
            --replay "$replay_candidate" \
            --baseline-output "$client_trace" \
            >"$client_log" 2>&1 &
    local client_pid=$!
    PIDS+=("$client_pid")

    set +e
    wait "$host_pid"
    local host_rc=$?
    wait "$client_pid"
    local client_rc=$?
    set -e
    PIDS=()
    if [[ $host_rc -ne 0 || $client_rc -ne 0 ]]; then
        echo "Network replay failed: host=$host_rc client=$client_rc" >&2
        echo "--- host log ---" >&2
        tail -60 "$host_log" >&2
        echo "--- client log ---" >&2
        tail -60 "$client_log" >&2
        return 1
    fi

    validate_trace_header "$host_trace" "network" "host"
    validate_trace_header "$client_trace" "network" "client"
    validate_hash_file "${host_trace}.state_hash"
    validate_hash_file "${client_trace}.state_hash"
    cmp -s "${host_trace}.state_hash" "${client_trace}.state_hash" \
        || fail "Network host and client final-state hashes differ."

    echo "  network state: $(<"${host_trace}.state_hash")"
    CANDIDATES=("$replay_candidate")
    DESTINATIONS=("$FIXTURE_DIR/replay_network.json")
}


generate_candidates() {
    case "$MODE" in
        hot-seat) generate_hot_seat_candidates ;;
        network) generate_network_candidates ;;
    esac
    echo "Candidate generation passed."
    for candidate in "${CANDIDATES[@]}"; do
        echo "  $(basename "$candidate"): $(hash_file "$candidate")"
    done
}


report_install_hashes() {
    echo "Installation comparison:"
    local index
    for index in "${!CANDIDATES[@]}"; do
        local destination="${DESTINATIONS[$index]}"
        local old_hash="ABSENT"
        if [[ -f "$destination" ]]; then
            old_hash="$(hash_file "$destination")"
        fi
        echo "  $(basename "$destination")"
        echo "    old: $old_hash"
        echo "    new: $(hash_file "${CANDIDATES[$index]}")"
    done
}


prepare_installation() {
    [[ -d "$FIXTURE_DIR" ]] || fail "Fixture directory is missing: $FIXTURE_DIR"
    INSTALL_EXISTED=()
    INSTALL_BACKUPS=()
    INSTALL_CHANGED=()

    local differing=false
    local index
    for index in "${!CANDIDATES[@]}"; do
        local candidate="${CANDIDATES[$index]}"
        local destination="${DESTINATIONS[$index]}"
        local backup="$TMP_DIR/backup_$index"
        if [[ -e "$destination" && ! -f "$destination" ]]; then
            fail "Canonical destination is not a regular file: $destination"
        fi
        if [[ -f "$destination" ]]; then
            INSTALL_EXISTED+=("1")
            INSTALL_BACKUPS+=("$backup")
            cp -p -- "$destination" "$backup"
            if cmp -s "$candidate" "$destination"; then
                INSTALL_CHANGED+=("0")
            else
                INSTALL_CHANGED+=("1")
                differing=true
            fi
        else
            INSTALL_EXISTED+=("0")
            INSTALL_BACKUPS+=("$backup")
            INSTALL_CHANGED+=("1")
        fi
    done

    report_install_hashes
    if $differing && ! $REPLACE_EXISTING; then
        fail "Canonical fixtures differ. Re-run with --install --replace-existing to replace them explicitly."
    fi
}


rollback_installation() {
    if ! $INSTALL_ACTIVE; then
        return 0
    fi
    echo "Rolling back baseline fixture installation..." >&2
    local rollback_failed=false
    local index
    for index in "${!DESTINATIONS[@]}"; do
        local destination="${DESTINATIONS[$index]}"
        if [[ "${INSTALL_EXISTED[$index]}" == "1" ]]; then
            cp -p -- "${INSTALL_BACKUPS[$index]}" "$destination" \
                || rollback_failed=true
            cmp -s "${INSTALL_BACKUPS[$index]}" "$destination" \
                || rollback_failed=true
        else
            rm -f -- "$destination" || rollback_failed=true
        fi
    done
    INSTALL_ACTIVE=false
    if $rollback_failed; then
        echo "ERROR: baseline fixture rollback was incomplete." >&2
        return 1
    fi
    echo "Rollback complete." >&2
}


write_installation() {
    local any_change=false
    local index
    for index in "${!INSTALL_CHANGED[@]}"; do
        if [[ "${INSTALL_CHANGED[$index]}" == "1" ]]; then
            any_change=true
            break
        fi
    done
    if ! $any_change; then
        echo "Canonical fixtures are already byte-identical; no files replaced."
        return 0
    fi

    INSTALL_ACTIVE=true
    for index in "${!CANDIDATES[@]}"; do
        if [[ "${INSTALL_CHANGED[$index]}" != "1" ]]; then
            continue
        fi
        local destination="${DESTINATIONS[$index]}"
        local staging="$(dirname "$destination")/.baseline_install_$$.$(basename "$destination")"
        STAGING_FILES+=("$staging")
        cp -- "${CANDIDATES[$index]}" "$staging"
        cmp -s "${CANDIDATES[$index]}" "$staging" \
            || fail "Staged fixture differs before installation: $destination"
        mv -f -- "$staging" "$destination"
    done
}


run_authoritative_verifier() {
    echo "Running authoritative verifier..."
    local verifier_mode="--$MODE"
    GODOT_BIN="$GODOT" "$VERIFIER" "$verifier_mode"
}


install_candidates() {
    prepare_installation
    write_installation
    if ! run_authoritative_verifier; then
        echo "Authoritative verifier failed." >&2
        rollback_installation
        return 1
    fi
    INSTALL_ACTIVE=false
    echo "Installation verified successfully."
}


cleanup() {
    local exit_code=$?
    local pid
    for pid in "${PIDS[@]:-}"; do
        if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
    if $INSTALL_ACTIVE; then
        rollback_installation || true
    fi
    local staging
    for staging in "${STAGING_FILES[@]:-}"; do
        if [[ -n "${staging:-}" ]]; then
            rm -f -- "$staging"
        fi
    done
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        case "$(basename "$TMP_DIR")" in
            armada_baseline_generate_*) rm -rf -- "$TMP_DIR" ;;
            *) echo "WARNING: refusing to remove unexpected temp path: $TMP_DIR" >&2 ;;
        esac
    fi
    return "$exit_code"
}


main() {
    parse_args "$@"
    require_tools
    resolve_repository_formats
    validate_replay_preflight
    find_godot
    prepare_temp_dir
    generate_candidates
    if $INSTALL; then
        install_candidates
    else
        echo "Candidate-only run complete; no repository fixture was changed."
    fi
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    main "$@"
fi
