require 'api_error'

class ApiRequestFailure < ApiError

  def initialize(subject, tags, response, data = {})
    super(subject, tags, data.merge({
                                        api_response: {
                                            status: response.code + ' ' + response.message,
                                            type:   response.content_type,
                                            length: response.content_length,
                                            body:   response.body.force_encoding('UTF-8'),

                                        },
                                    }))
  end

end
