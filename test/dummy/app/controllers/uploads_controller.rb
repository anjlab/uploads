class UploadsController < ApplicationController
  include Uploads

  def create
    # upload = Upload.new
    respond_to_upload(request) do |file, response|
      # upload.file = file
      response[:success] = true #upload.save
        # todo: thumb
      # end
    end
  end


end