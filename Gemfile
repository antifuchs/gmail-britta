source "https://rubygems.org"

# We require ruby 2.1.0 or above:
ruby ">= 2.1.0"

gem 'haml', '~> 3.1.6'
gem "simplecov", group: :test, require: nil


# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "rake", ">= 0.9.2"
  gem "bundler", ">= 1.2.0"
  gem "minitest"
  gem "nokogiri", "~> 1.8.1"
  gem "pry"
end

group :doc do
  gem "rdoc", "~> 3.12"
  gem "yard", '~> 0.9.11'
  gem 'redcarpet', '~> 2.2.2'
end

group :release do
  gem "juwelier"
end

gemspec
