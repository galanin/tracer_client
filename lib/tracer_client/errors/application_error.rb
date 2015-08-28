class ApplicationError < StandardError

  attr_reader :tags, :data


  def initialize(subject, tags = '', data = {})
    super(subject)
    @tags = tags
    @data = data

    puts "#{'-'*10}\n#{@data}\n#{'-'*10}" if Rails.env.development?

    Log.on_raise(self, caller(2))
  end


  # для логирования при бросании и в дефолтном обработчике
  def with_log?
    self.class.name.end_with?('Log', 'Alert')
  end


  # для логирования при бросании и в дефолтном обработчике
  def with_alert?
    self.class.name.end_with?('Alert')
  end

end
