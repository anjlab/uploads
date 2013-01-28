class UploadsController < ApplicationController
  def create
    file = MechanizeClip.from_raw(request)
    render text: '{"success": true}', status: :ok
  end
end