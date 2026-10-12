json.summary "#{@accounts.size} #{"ad account".pluralize(@accounts.size)}#{" needing attention" if @show == "attention"}"
json.accounts @accounts do |account|
  summary = account.summary
  json.merge! agent_ref(account)
  json.url ads_checklist_account_url(account)
  json.extract! account, :name, :platform, :external_id
  json.website account.url
  json.client agent_ref(account.client)
  json.checklist summary.to_h
  json.needs_attention ad_account_attention_text(account, summary)
  json.next_step account.next_item&.title
end
