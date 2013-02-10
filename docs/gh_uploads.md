
1. Create new rails app
```sh
rails new gh_uploads --skip-bundle
```

2. Add gems slim, uploads and paperclip
```sh
echo "gem 'slim-rails'\ngem 'uploads'\ngem 'paperclip'" >> gh_uploads/Gemfile
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

