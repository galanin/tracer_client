require 'config'

module Tracer
  module Server

    def self.log(notice_hash)
      if Rails.env.production? && !ENV['NO_TRACER'].to_b || Rails.env.development? && ENV['TRACER'].to_b
        send("http://#{Settings.tracer.host}:#{Settings.tracer.port}/api/v3/project/#{Settings.tracer.project}/notices?api_key=#{Settings.tracer.api_key}", notice_hash)
      end
    end


    def self.log_changes(changes_hash)
      Rails.logger.debug "Log change: #{changes_hash.inspect}"
      if Rails.env.production? && !ENV['NO_TRACER'].to_b || Rails.env.development? && ENV['TRACER'].to_b
        send("http://#{Settings.tracer.host}:#{Settings.tracer.port}/api/v3/projects/#{Settings.tracer.project}/changes?api_key=#{Settings.tracer.api_key}", changes_hash)
      end
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