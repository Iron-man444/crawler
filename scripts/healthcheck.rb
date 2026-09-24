require "net/http"
require "json"
config = JSON.parse(File.read("config/settings.json"))
http = Net::HTTP.new("127.0.0.1", config.fetch("port"), nil)
http.open_timeout = 3
http.read_timeout = 3
request = Net::HTTP::Get.new("/api/v1/status")
request["Authorization"] = "Bearer #{ENV.fetch('RADAR_API_TOKEN')}"
exit(http.request(request).code == "200" ? 0 : 1)
