#!/usr/bin/env ruby
require "json"
require_relative "../lib/radar/http"
require_relative "../lib/radar/telegram"

begin
  bot = Radar::Telegram.new(client: nil, token: ENV.fetch("TELEGRAM_BOT_TOKEN"),
    targets: JSON.parse(ENV.fetch("TELEGRAM_TARGETS")))
  id = bot.test_message
  puts "Telegram test mesajı gönderildi (message_id=#{id}). Gemini ve tarama henüz test edilmedi."
rescue Radar::WorkError => e
  warn "Telegram testi: #{e.code}"
  warn "400: chat ID veya /start; 401/404: bot token; 403: bot engeli/izin; 429: hız sınırı."
  warn "Teslim belirsizse yeniden denemeden önce Telegram sohbetini kontrol edin." if e.code == "telegram_test_delivery_unknown"
  exit 1
rescue StandardError => e
  warn "Telegram test ayarları okunamadı (#{e.class}). .env içindeki TELEGRAM_BOT_TOKEN ve TELEGRAM_TARGETS değerlerini kontrol edin."
  exit 1
end
