
1. Create new rails app
```sh
rails new gh_uploads --skip-bundle
```

2. Add slim, uploads, html-pipeline and paperclip gems
```sh
echo "gem 'slim-rails'\ngem 'uploads'\ngem 'paperclip'\ngem 'html-pipeline'" >> gh_uploads/Gemfile
```

3. Bundle install
```sh
cd gh_uploads && bundle install
```

4. Add anjlab/uploads to application.js
```sh
ruby -i -pe 'puts "//= require anjlab/uploads" if $_ =~ /_tree/' app/assets/javascripts/application.js
```

5. Create Upload model
```sh
rails g resource Upload image:attachment image_fingerprint --fixture false && rake db:migrate
```

6. Create Message model
```sh
rails g scaffold Message body:text --fixture false && rake db:migrate
```

7. Point root route to messages#index and rm public/index.html
```sh
ruby -i -pe '$_= "  root to: \047messages#index\047" if $_ =~ /# root/' config/routes.rb
rm public/index.html
```

8. Change your Upload model

```ruby
class Upload < ActiveRecord::Base
  
  has_attached_file :image,
    url: "/system/:class/:id/:style-:fingerprint.:extension",
    default_url: "/assets/:class/:style-missing.jpg",
    use_timestamp: false

end
```

9. Change your uploads_controller.rb

```ruby
class UploadsController < ApplicationController
  include Uploads

  def create
    @upload = Upload.new

    respond_to_upload(request) do |file, response|
      # grab uploaded file
      @upload.image = file
      # try to save it
      if response[:success] = @upload.save
        response[:image_url] = @upload.image.url(:original)
      else
        # report errors if any
        response[:errors] = @upload.errors
      end
    end
  end
end
```
