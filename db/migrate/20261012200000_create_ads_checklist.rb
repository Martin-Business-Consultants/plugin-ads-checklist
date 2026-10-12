# The Ads plugin's tables, prefixed with its key. Clients and todos are the core's, pointed at by
# id. An account's steps go with it; its history (audits) outlives it, so has no foreign keys.
class CreateAdsChecklist < ActiveRecord::Migration[8.1]
  def change
    create_table :ads_checklist_accounts do |t|
      t.integer :client_id, null: false, index: true
      t.string :platform, null: false
      t.string :name, null: false
      t.string :external_id
      t.string :url
      t.timestamps
    end

    create_table :ads_checklist_items do |t|
      t.references :account, null: false, foreign_key: { to_table: :ads_checklist_accounts }
      t.string :key, null: false
      t.string :group, null: false
      t.string :title, null: false
      t.text :detail
      t.text :value
      t.text :confirmed_value
      t.string :state, null: false, default: "unconfirmed"
      t.text :note
      t.string :confirmed_by_name
      t.datetime :confirmed_at
      t.integer :position, null: false, default: 0
      t.boolean :custom, null: false, default: false
      t.timestamps
      t.index %i[account_id key], unique: true
    end

    create_table :ads_checklist_webhooks do |t|
      t.references :item, null: false, foreign_key: { to_table: :ads_checklist_items }
      t.string :name
      t.string :url
      t.text :pairs
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :ads_checklist_audits do |t|
      t.integer :account_id, index: true
      t.string :account_name
      t.integer :item_id, index: true
      t.string :record_type, null: false
      t.integer :record_id
      t.string :record_label
      t.string :action, null: false
      t.text :diff
      t.integer :actor_id, index: true
      t.string :actor_name
      t.string :source
      t.string :via
      t.datetime :created_at, null: false
    end

    create_table :ads_checklist_scans do |t|
      t.references :account, null: false, foreign_key: { to_table: :ads_checklist_accounts }
      t.integer :user_id, null: false
      t.string :domain, null: false
      t.string :state, null: false, default: "queued"
      t.text :facts
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :ads_checklist_recommendations do |t|
      t.references :scan, null: false, foreign_key: { to_table: :ads_checklist_scans }
      t.references :item, null: false, foreign_key: { to_table: :ads_checklist_items }
      t.text :value
      t.text :note
      t.text :evidence
      t.string :confidence
      t.string :attach_file
      t.string :state, null: false, default: "pending"
      t.string :decided_by_name
      t.datetime :decided_at
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :ads_checklist_todo_links do |t|
      t.references :account, null: false, foreign_key: { to_table: :ads_checklist_accounts }
      t.references :item, foreign_key: { to_table: :ads_checklist_items }
      t.integer :todo_id, null: false, index: true
      t.timestamps
    end
  end
end
