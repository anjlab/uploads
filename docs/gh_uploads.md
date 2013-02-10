
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

4. Create Upload model
```sh
rails g resource Upload image:attachment image_fingerprint --fixture false && rake db:migrate
```

5. Create Message model
```sh
rails g scaffold Message body:text --fixture false && rake db:migrate
```

6. Point root route to messages#index and rm public/index.html
```sh
ruby -i -pe '$_= "  root to: \047messages#index\047" if $_ =~ /# root/' config/routes.rb
rm public/index.html
```

7. Add anjlab/uploads to application.js
```sh
ruby -i -pe 'puts "//= require anjlab/uploads" if $_ =~ /_tree/' app/assets/javascripts/application.js
```

