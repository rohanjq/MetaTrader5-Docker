#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace_dir=$(dirname "$script_dir")

mt5_dir=${MT5_REPO_DIR:-"$script_dir"}
ohlc_dir=${OHLC_REPO_DIR:-"$workspace_dir/ohlc"}
signals_dir=${SIGNALS_REPO_DIR:-"$workspace_dir/signals"}
stream_dir=${STREAM_REPO_DIR:-"$workspace_dir/stream"}
compose=${COMPOSE_COMMAND:-podman-compose}
wait_seconds=${STACK_WAIT_SECONDS:-180}

usage() {
    echo "usage: $0 {up [--build]|down|restart [--build]|status|logs}" >&2
    exit 2
}

require_file() {
    if [ ! -f "$1" ]; then
        echo "missing required file: $1" >&2
        exit 1
    fi
}

env_value() {
    file=$1
    key=$2
    fallback=$3
    value=$(sed -n "s/^${key}=//p" "$file" | tail -n 1)
    printf '%s\n' "${value:-$fallback}"
}

compose_in() {
    repo=$1
    file=$2
    shift 2
    (cd "$repo" && "$compose" -f "$file" "$@")
}

wait_http() {
    name=$1
    url=$2
    require_success=$3
    elapsed=0

    echo "waiting for $name at $url"
    while [ "$elapsed" -lt "$wait_seconds" ]; do
        if [ "$require_success" = true ]; then
            if curl -fsS --max-time 2 -o /dev/null "$url" 2>/dev/null; then
                echo "$name is ready"
                return 0
            fi
        elif curl -sS --max-time 2 -o /dev/null "$url" 2>/dev/null; then
            echo "$name is ready"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo "timed out waiting for $name after ${wait_seconds}s" >&2
    return 1
}

up_stack() {
    build_arg=${1:-}
    if [ -n "$build_arg" ] && [ "$build_arg" != "--build" ]; then
        usage
    fi

    command -v "$compose" >/dev/null 2>&1 || {
        echo "$compose is not installed" >&2
        exit 1
    }
    command -v curl >/dev/null 2>&1 || {
        echo "curl is not installed" >&2
        exit 1
    }

    require_file "$mt5_dir/.env"
    require_file "$ohlc_dir/.env"
    require_file "$signals_dir/.env"
    require_file "$stream_dir/.env"
    ohlc_port=$(env_value "$ohlc_dir/.env" OHLC_HTTP_PORT 8080)
    signals_port=$(env_value "$signals_dir/.env" SIGNALD_HTTP_PORT 8090)

    echo "[1/4] Starting MetaTrader 5"
    if [ -n "$build_arg" ]; then
        compose_in "$mt5_dir" docker-compose.live.yaml up -d --build
    else
        compose_in "$mt5_dir" docker-compose.live.yaml up -d
    fi
    wait_http "MetaTrader KasmVNC" "http://127.0.0.1:3000/" false

    echo "[2/4] Starting OHLC"
    if [ -n "$build_arg" ]; then
        compose_in "$ohlc_dir" docker-compose.yml up -d --build
    else
        compose_in "$ohlc_dir" docker-compose.yml up -d
    fi
    wait_http "OHLC" "http://127.0.0.1:${ohlc_port}/healthz" true

    echo "[3/4] Starting Signals"
    if [ -n "$build_arg" ]; then
        compose_in "$signals_dir" compose.yaml up -d --build
    else
        compose_in "$signals_dir" compose.yaml up -d
    fi
    wait_http "Signals" "http://127.0.0.1:${signals_port}/healthz" true

    if ! curl -fsS --max-time 5 -o /dev/null "http://127.0.0.1:${ohlc_port}/readyz" 2>/dev/null; then
        echo "warning: OHLC is running but not data-ready; check its provider credentials" >&2
    fi
    if ! curl -fsS --max-time 5 -o /dev/null "http://127.0.0.1:${signals_port}/readyz" 2>/dev/null; then
        echo "warning: Signals is running but waiting for its upstream data" >&2
    fi

    echo "[4/4] Starting Stream"
    if [ -n "$build_arg" ]; then
        compose_in "$stream_dir" compose.yaml up -d --build
    else
        compose_in "$stream_dir" compose.yaml up -d
    fi
    wait_http "Stream" "http://127.0.0.1:8080/api/health" true
    wait_http "Stream compositor" "http://127.0.0.1:7800/health" true

    echo "stack services started"
}

down_stack() {
    compose_in "$stream_dir" compose.yaml down
    compose_in "$signals_dir" compose.yaml down
    compose_in "$ohlc_dir" docker-compose.yml down
    compose_in "$mt5_dir" docker-compose.live.yaml down
}

status_stack() {
    echo "MetaTrader 5"
    compose_in "$mt5_dir" docker-compose.live.yaml ps
    echo "OHLC"
    compose_in "$ohlc_dir" docker-compose.yml ps
    echo "Signals"
    compose_in "$signals_dir" compose.yaml ps
    echo "Stream"
    compose_in "$stream_dir" compose.yaml ps
}

logs_stack() {
    compose_in "$mt5_dir" docker-compose.live.yaml logs --tail 40
    compose_in "$ohlc_dir" docker-compose.yml logs --tail 40
    compose_in "$signals_dir" compose.yaml logs --tail 40
    compose_in "$stream_dir" compose.yaml logs --tail 40
}

case "${1:-}" in
    up)
        shift
        [ "$#" -le 1 ] || usage
        up_stack "${1:-}"
        ;;
    down)
        [ "$#" -eq 1 ] || usage
        down_stack
        ;;
    restart)
        shift
        [ "$#" -le 1 ] || usage
        [ "$#" -eq 0 ] || [ "$1" = "--build" ] || usage
        build_arg=${1:-}
        down_stack
        up_stack "$build_arg"
        ;;
    status)
        [ "$#" -eq 1 ] || usage
        status_stack
        ;;
    logs)
        [ "$#" -eq 1 ] || usage
        logs_stack
        ;;
    *) usage ;;
esac
