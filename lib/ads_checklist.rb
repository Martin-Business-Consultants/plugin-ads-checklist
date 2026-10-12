require "ads_checklist/version"
require "ads_checklist/engine"

# Ads: each client's Google Ads and Meta Ads accounts, and for each the steps to take it live, in
# order: access and billing first, then tracking, the campaigns, launch and after launch. A person
# records what each step needs and confirms it.
module AdsChecklist
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "ads_checklist_"
end
