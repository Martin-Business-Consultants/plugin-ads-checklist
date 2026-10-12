require_relative "lib/ads_checklist/version"

# The gemspec's name is the plugin's key and its table prefix.
Gem::Specification.new do |spec|
  spec.name = "ads_checklist"
  spec.version = AdsChecklist::VERSION
  spec.summary = "Ads for Runwell: every client's Google Ads and Meta Ads accounts, set up step by step, recorded and confirmed"
  spec.authors = [ "Martin Business Consultants" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/plugin-ads-checklist"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
