$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "uploads/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "uploads"
  s.version     = Uploads::VERSION
  s.authors     = ["Yury Korolev"]
  s.email       = ["yury.korolev@gmail.com"]
  s.homepage    = "https://github.com/anjlab/uploads"
  s.summary     = "Simplified uploads for rails"
  s.description = "Simplified uploads for rails"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.2"
  s.add_dependency "mechanize_clip"

  s.add_development_dependency "sqlite3"
end
