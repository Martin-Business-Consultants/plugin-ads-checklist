json.summary "#{@audits.size} #{"change".pluralize(@audits.size)}#{" to #{@item&.title || @account.name}" if @account}, newest first"
json.audits @audits do |audit|
  json.extract! audit, :id, :created_at, :action, :source, :account_id, :account_name, :item_id, :record_type, :record_id
  json.who audit.actor_label
  json.subject audit.subject_label
  json.changes(audit.diff.map { |field, (before, after)| { field: AdsChecklist::Audit.field_label(field), before: before, after: after } })
end
json.older_before @older
