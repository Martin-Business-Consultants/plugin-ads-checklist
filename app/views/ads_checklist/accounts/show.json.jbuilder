summary = @account.summary
next_item = @account.next_item
json.merge! agent_ref(@account)
json.url ads_checklist_account_url(@account)
json.summary "#{@account.name}: #{summary}#{"; next: #{next_item.title}" if next_item}"
json.extract! @account, :name, :platform, :external_id
json.website @account.url
json.client agent_ref(@account.client)
json.checklist summary.to_h
json.next_step next_item && { id: next_item.id, title: next_item.title }
json.items ad_account_item_groups(@items).flat_map(&:last).each_with_index.to_a do |(item, index)|
  json.step index + 1
  json.extract! item, :id, :key, :group, :title, :detail, :how, :example, :value, :confirmed_value, :state, :note,
    :confirmed_by_name, :confirmed_at, :custom
  json.files item.files.attachments do |file|
    json.id file.id
    json.filename file.filename.to_s
    json.byte_size file.byte_size
    json.url rails_blob_url(file, disposition: "attachment")
  end
  if item.webhooks?
    json.webhooks item.webhooks do |webhook|
      json.extract! webhook, :id, :name, :url, :pairs
    end
  end
end
