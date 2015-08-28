require 'config'

module Tracer
  module Server

    def self.log(notice_hash)
      send("http://#{Settings.tracer.host}:#{Settings.tracer.port}/api/v3/projects/#{Settings.tracer.project}/notices?api_key=#{Settings.tracer.api_key}", notice_hash)
    end


    def self.log_changes(changes_hash)
      Rails.logger.debug "Log change: #{changes_hash.inspect}"
      send("http://#{Settings.tracer.host}:#{Settings.tracer.port}/api/v3/projects/#{Settings.tracer.project}/changes?api_key=#{Settings.tracer.api_key}", changes_hash)
    end


    private


    def self.send(url, data)
      uri = URI.parse(url)

      Net::HTTP.start(uri.host, uri.port, read_timeout: 20) do |http|
        http.request_post(uri.path + '?' + uri.query, JSON.dump(data), 'Content-Type' => 'text/xml; charset=utf-8') do |response|
          return true if Net::HTTPNoContent === response
          Rails.logger.error "Tracer request url: #{url}"
          Rails.logger.error "Tracer response #{response.inspect}: #{response.body.inspect}"
        end
      end
    rescue Exception => e
      Rails.logger.error "Tracer request url: #{url}"
      Rails.logger.error "Tracer exception #{e.inspect}: #{e.message}"
    end

  end
end