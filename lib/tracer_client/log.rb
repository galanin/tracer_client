require 'config'
require 'tracer_client/client'

module Log

  # error - ошибки
  # crit  - исключения
  # emerg - неперехваченные исключения
  SEVERITIES = %i(debug info notice warn error crit alert emerg)
  FACILITIES = %i(request lib auth user product order line_item delivery odkl email direct_mail page exception)

  ROBOT_UA_FRAGMENTS = /AhrefsBot|bingbot|DotBot|Googlebot|Mail.RU_Bot|MJ12bot|msnbot|SputnikBot|updown_tester|Web-Monitoring|WebMasterAid|YaDirectFetcher|Yahoo! Slurp|YandexBot/


  def self.start_request(current_user, request, params, session, do_log_request)
    Tracer::Client.start_request(current_user, request, params, session)

    info('HTTP запрос', 'http_request') if do_log_request

    Thread.current[:request_tags] = %w(robot) if request.headers['User-Agent'] =~ ROBOT_UA_FRAGMENTS
  end

  def self.end_request
    Thread.current[:request_tags] = nil
    Tracer::Client.end_request
  end


  # Можно вызывать в сокращённой форме:
  # Log.debug('Сообщение')
  # Log.debug({a: 2, b: 5})
  # Log.debug(any_object)
  def self.debug(subject = '', tags = '', data = {})
    if Hash === subject
      # передан только хэш с данными
      message(:debug, subject.inspect[0...40], '', subject, caller)
    elsif String === subject
      # передан только subject
      message(:debug, subject, tags, data, caller)
    else
      # переданы некие другие данные
      message(:debug, subject.inspect[0...40], '', {debug: subject}, caller)
    end
  end


  %i(info warn error).each do |base_method|
    instance_eval <<-CODE, __FILE__, __LINE__ + 1
      def #{base_method}(subject, tags = '', data = {})
        message(:#{base_method}, subject, tags, data, caller)
      end

      def #{base_method}_with_alert(subject, tags = '', data = {})
        message(:#{base_method}, subject, tags, data.merge(with_alert: true), caller)
      end
    CODE
  end


  def self.exception(exception, subject, tags = '', data = {})
    if Rails.env.development?
      raise exception
    else
      exception_message(exception, :crit, subject, tags, data, exception.backtrace)
      exception
    end
  end


  def self.exception_with_alert(exception, subject, tags = '', data = {})
    exception(exception, subject, tags, data.merge(with_alert: true))
  end


  def self.on_raise(exception, backtrace)
    if exception.with_log?
      exception_message(exception, :warn, '', 'raise', {with_alert: exception.with_alert?}, backtrace)
    end
  end


  def self.unhandled(exception)
    if exception.with_log? && !exception.logged?
      exception_message(exception, :emerg, '', 'unhandled', {with_alert: exception.with_alert?}, exception.backtrace)
    end
  end


  private


  def self.message(severity, subject, tags, data, backtrace)
    return unless log?(severity)

    tags = (Thread.current[:request_tags] || []) + tags.split(' ')

    data = {data: data} unless Hash === data

    return if data.key?(:exception) && data[:exception][:class] == 'ActiveRecord::RecordNotFound' && tags == %w(robot)

    error_hash = {
        severity:          severity,
        tags:              tags,
        message:           subject,
        backtrace: get_backtrace(backtrace).first(10)
    }

    if data.key?(:exception)
      error_hash[:exception_message] = data[:exception][:message].strip
      error_hash[:type]              = data[:exception][:class]
    end

    Tracer::Client.log(
        errors: [error_hash],
        data:       data.except(:exception, :with_alert),
        with_alert: data[:with_alert],
    )
  end


  def self.exception_message(exception, severity, subject, tags, data, backtrace)
    tags = (tags + ' ' + exception.tags).strip if exception.respond_to?(:tags)
    data.merge!(exception.data.except(:with_alert)) if exception.respond_to?(:data)
    data.merge!(exception: {
                    class:   exception.class.name,
                    message: exception.message
                })

    message(severity, subject, tags, data, backtrace)
    exception.mark_logged
  end


  def self.log?(severity)
    (Rails.env.production? && !ENV['NO_TRACER'].to_b || ENV['TRACER'].to_b) &&
      (Settings.log.severity_level.nil? || enabled_severity?(severity, Settings.log.severity_level))
  end

  def self.enabled_severity?(message_severity, configured_severity)
    message_index = SEVERITIES.index(message_severity)
    configured_index = SEVERITIES.index(configured_severity.to_sym)
    message_index.nil? || configured_index.nil? || message_index >= configured_index
  end

  def self.get_backtrace(backtrace)
    locations = Rails.backtrace_cleaner.clean(backtrace || [])

    locations.map do |location|
      if location =~ /\A(.*):(\d+):\s*(?:in `(.*)')\z/
        {
            file:     $~[1],
            line:     $~[2],
            function: $~[3],
        }
      end
    end.compact
  end

end
