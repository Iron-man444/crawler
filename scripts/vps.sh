#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
action="${1:-start}"
if [[ $# -gt 0 ]]; then shift; fi
if [[ "$EUID" -eq 0 ]]; then
  docker_cmd=(docker)
else
  docker_cmd=(sudo docker)
fi
case "$action" in
  test)
    "${docker_cmd[@]}" compose -f compose.tools.yaml run --rm telegram-test
    ;;
  start)
    echo "Önce Telegram test mesajı gönderiliyor; tarama sonucu beklenmez."
    "${docker_cmd[@]}" compose -f compose.tools.yaml run --rm telegram-test
    "${docker_cmd[@]}" build -t firsat-radari:pilot .
    # Finish fallible preparation before stopping the running workers.
    "${docker_cmd[@]}" run --rm --user "$(id -u):$(id -g)" -v "$PWD/config:/app/config" firsat-radari:pilot ruby scripts/setup_pilot.rb "$@"
    "${docker_cmd[@]}" run --rm -v "$PWD/config:/app/config:ro" firsat-radari:pilot ruby bin/radar validate
    "${docker_cmd[@]}" compose build radar telegram
    "${docker_cmd[@]}" compose stop telegram radar
    "${docker_cmd[@]}" compose up -d --force-recreate
    echo "Servisler başlatıldı. Durum: bash scripts/vps.sh status | Log: bash scripts/vps.sh logs"
    ;;
  status)
    "${docker_cmd[@]}" compose ps
    "${docker_cmd[@]}" compose exec radar ruby bin/radar status
    "${docker_cmd[@]}" compose exec radar ruby bin/radar review
    ;;
  logs) "${docker_cmd[@]}" compose logs --tail=100 -f radar telegram ;;
  stop) "${docker_cmd[@]}" compose stop telegram radar ;;
  *) echo "Kullanım: bash scripts/vps.sh {test|start [--provider gemini|mistral] [--model MODEL] [--sources 50] [--all]|status|logs|stop}" >&2; exit 2 ;;
esac
