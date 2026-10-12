module AdsChecklist
  # A client's ad account on one platform (Google Ads or Meta) and the checklist to take it live:
  # what to gather and record, step by step, each recorded and confirmed by a person.
  class Account < ApplicationRecord
    include Audited

    PLATFORMS = { "google" => "Google Ads", "meta" => "Meta Ads" }.freeze
    # What each platform calls the account's ID, and what one looks like.
    EXTERNAL_IDS = { "google" => [ "Customer ID", "123-456-7890" ], "meta" => [ "Ad account ID", "act_1234567890" ] }.freeze

    Summary = Data.define(:total, :confirmed, :unconfirmed, :not_applicable) do
      def ready? = total.positive? && confirmed == total
      def to_h = super.merge(ready: ready?)
      def to_s = ready? ? "All #{total} confirmed" : "#{confirmed} of #{total} confirmed"
    end

    # Before the items go, without a callback each: what points at them, and their files.
    before_destroy do
      Webhook.where(item_id: items.select(:id)).delete_all
      Recommendation.where(item_id: items.select(:id)).delete_all
      todo_links.delete_all
      ActiveStorage::Attachment.where(record_type: Item.name, record_id: items.select(:id)).find_each(&:purge_later)
    end

    belongs_to :client
    has_many :items, -> { ordered }, dependent: :delete_all
    has_many :scans, dependent: :destroy
    has_many :todo_links, dependent: :delete_all

    normalizes :url, with: ->(url) { url.strip.chomp("/").presence }
    normalizes :name, with: ->(name) { name.strip }
    normalizes :external_id, with: ->(id) { id.strip.presence }

    validates :name, presence: true
    validates :platform, inclusion: { in: PLATFORMS.keys, message: "must be Google Ads or Meta Ads" }
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_nil: true

    after_create :apply_standard_checklist

    scope :ordered, -> { order(:name) }

    def host
      URI.parse(url.to_s).host || url
    rescue URI::InvalidURIError
      url
    end

    def revise(attributes) = update(attributes)

    def platform_name = PLATFORMS.fetch(platform, platform.to_s)
    def external_id_label = EXTERNAL_IDS.dig(platform, 0) || "Account ID"
    def external_id_example = EXTERNAL_IDS.dig(platform, 1)

    # Counts over the items that apply (not the ones marked not applicable).
    def summary
      list = items.to_a
      applicable = list.reject(&:not_applicable?)
      Summary.new(total: applicable.size, confirmed: applicable.count(&:confirmed?),
        unconfirmed: applicable.count { !it.confirmed? }, not_applicable: list.size - applicable.size)
    end

    def needs_attention? = !summary.ready?

    def to_s = name

    # The first step still to do, in order: where the checklist picks up.
    def next_item = items.find { !it.settled? }

    # The platform's standard checklist (Account::Defaults), added where missing and put in its
    # order with its current wording. Custom items follow, in the order they were added.
    def apply_standard_checklist
      existing = items.reload.index_by(&:key)
      now = Time.current
      Defaults.for(platform).each_with_index do |default, index|
        attributes = default.slice(:group, :title, :detail).merge(position: index * 10)
        if (item = existing[default[:key]])
          item.update_columns(attributes.merge(updated_at: now)) if attributes.any? { |name, value| item[name] != value }
        else
          Item.insert!(attributes.merge(key: default[:key], account_id: id, created_at: now, updated_at: now))
        end
      end
      items.reset
    end

    private
      def audit_account = self
      def audit_value(field, value)
        case field
        when "client_id" then Client.find_by(id: value)&.name
        when "platform" then PLATFORMS[value]
        else super
        end
      end
  end
end
