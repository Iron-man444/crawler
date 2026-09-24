require "json"
require "digest"
require "time"
require "date"
require "securerandom"
require "logger"
require_relative "radar/config"
require_relative "radar/http"
require_relative "radar/extractor"
require_relative "radar/analyzer"
require_relative "radar/filter"
require_relative "radar/store"
require_relative "radar/runner"
require_relative "radar/api"

module Radar
  VERSION = "0.1.0"
  def self.digest(value)
    Digest::SHA256.hexdigest(value.is_a?(String) ? value : JSON.generate(value))
  end
end
