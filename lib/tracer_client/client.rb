require 'tracer_client/server'

module Tracer
  module Client

    class << self

      def start_request(current_user, request, params, session)
        Thread.current[:tracer_current_user] = current_user
        Thread.current[:tracer_request] = request
        Thread.current[:tracer_params] = get_params(params)
      end


      def end_request
        Thread.current[:tracer_current_user] = nil
        Thread.current[:tracer_request] = nil
        Thread.current[:tracer_params] = nil
      end


      def log(notice)
        Thread.new do
          Tracer::Server.log(notice.merge(request_log_data))
        end
      end


      def log_changes(changes)
        Thread.new do
          Tracer::Server.log_changes(changes.merge(request_changes_data))
        end
      end


      private


      def get_params(params)
        @parameter_filter ||= ActionDispatch::Http::ParameterFilter.new Rails.application.config.filter_parameters
        @parameter_filter.filter(params.except(:utf8, :authenticity_token, :_method)).symbolize_keys
      end


      def request_data
        data = {context: {}}

        request = Thread.current[:tracer_request]
        if request
          data[:context].merge!(
              url:        request.original_url,
              referer:    request.headers['Referer'],
              user_agent: request.headers['User-Agent'],
              ip:         request.remote_ip,
              method:     request.request_method,
              request_id: request.uuid,
              headers:    {
                  accept: request.headers['Accept'],
              }
          )
        end

        cookies = Thread.current[:cookies]
        if cookies && cookies[:administrator_id]
          data[:context][:cookies] = {
              administrator_id: cookies.signed[:administrator_id]
          }
        end

        current_user = Thread.current[:tracer_current_user]
        if current_user
          data[:context].merge!(
              userType: current_user[:type],
              userId:   current_user[:id],
          )
        end

        params = Thread.current[:tracer_params]
        if params
          data[:context].merge!(
              component: params[:controller],
              action:    params[:action],
          )
          data[:params] = params.except(:controller, :action)
        end

        data[:context].merge!(
            environment:   Rails.env,
            rootDirectory: Rails.root,
        )

        data
      end


      def request_log_data
        request_data
      end


      def request_changes_data
        request_data
      end

    end

  end
end
