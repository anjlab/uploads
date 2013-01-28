= Uploads

## Installation

Add it to our Gemfile

```ruby
gem 'uploads'
```

## In your controller

```ruby
class UserUploadsController < ApplicationController
  # includes Uploads module for #respond_to_upload method
  include Uploads

  def create
    # create you Upload model as usual
    @upload = current_user.user_uploads.new
    
    respond_to_upload(request) do |file, response|
      # grab uploaded file
      @upload.image = file
      # try to save it
      if response[:success] = @upload.save
        # send back upload id and image preview
        response[:user_upload_id] = @upload.id
        response[:user_upload_preview_url] = @upload.image.url(:avator_editor)
      else
        # report errors if any
        response[:errors] = @upload.errors
      end
    end
  end
end

```

## In your views

```slim
  #upload-area data-button='#upload-button' data-multiple='false' data-dropzones='#upload-area'
    a#upload-button Choose a photo
```

This project rocks and uses MIT-LICENSE.