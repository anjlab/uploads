# Uploads - Easy uploads for rails.

1. No predefined CSS and templates.
2. Support rails CSRF TOKEN.
3. No middleware, just your controllers.
4. Use as much as possible jQuery buildin functions.
5. Works Paperclip and CarrierWave
6. Based on [file-uploader](https://github.com/valums/file-uploader/)

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
  #upload-area data-button='#upload-button' \
               data-multiple='false' \
               data-dropzones='#upload-area'
    a#upload-button Choose a photo
```

## In your js

```coffeescript
# application.js.coffee
...
# require anjlab/uploads
```

```coffeescript
  $('#upload-area').uploader
    request:
      endpoint: '/user_uploads'
    validation:
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif']
    callbacks:
      onComplete: (id, fileName, response) ->
        console.log('onComplete')
      onProgress: (id, fileName, loaded, total) ->
        console.log('onProgress')
      onUpload: (id, fileName) ->
        console.log('onUpload')
      onError: (id, fileName, message) ->
        console.log('onError')
```

## Examples and tutorials

![uploads](https://f.cloud.github.com/assets/5250/523901/814e1f4a-c0ea-11e2-92b8-e50647185e26.gif)

- [Github like issues attachments](docs/gh_uploads.md)

This project rocks and uses MIT-LICENSE.
