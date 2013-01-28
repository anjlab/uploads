module Uploads
  def respond_to_upload(request)
    response = {success: false}
    file = MechanizeClip.from_raw(request)
    yield(file, response) if block_given?
    render text: response.to_json, status: :ok
  end
end

require 'uploads/engine' if defined?(Rails)
