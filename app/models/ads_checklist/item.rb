module AdsChecklist
  # One step to take an ad account live: an access to get, a setting to record, a check to make. A
  # person records its value and confirms it; what they confirmed is kept (`confirmed_value`), so
  # a value changed later is to confirm again. The standard steps' guidance (`how`, `example`) is
  # read from Account::Defaults.
  class Item < ApplicationRecord
    include Audited

    GROUPS = [ *Account::Defaults::GROUPS, "Custom" ].freeze
    STATES = %w[unconfirmed confirmed not_applicable].freeze
    STATE_LABELS = { "unconfirmed" => "To do", "confirmed" => "Confirmed", "not_applicable" => "Not applicable" }.freeze

    belongs_to :account, touch: true
    has_many :webhooks, -> { ordered }, dependent: :delete_all, inverse_of: :item
    accepts_nested_attributes_for :webhooks, allow_destroy: true, reject_if: :blank_webhook?
    has_many :recommendations, dependent: :delete_all
    has_many :todo_links, dependent: :delete_all
    has_many_attached :files

    validates :key, presence: true, uniqueness: { scope: :account_id }
    validates :title, :group, presence: true
    validates :state, inclusion: { in: STATES }

    normalizes :value, :note, with: ->(text) { text.strip.presence }

    scope :ordered, -> { order(:position, :id) }

    # An item of the team's own, beyond the standard checklist (Custom).
    def self.add_custom(account, title:, detail: nil, value: nil, note: nil)
      account.items.create(key: "custom:#{SecureRandom.hex(4)}", group: "Custom", title: title, detail: detail,
        value: value, note: note, custom: true, position: (account.items.maximum(:position) || 0) + 1)
    end

    def state_label = STATE_LABELS.fetch(state)
    def confirmed? = state == "confirmed"
    def not_applicable? = state == "not_applicable"
    def settled? = confirmed? || not_applicable?

    def how = Account::Defaults::BY_KEY.dig(key, :how)
    def example = Account::Defaults::BY_KEY.dig(key, :example)

    # The lead webhooks step (google:webhooks, meta:webhooks) records each webhook (name, address,
    # keys and values) rather than a line of text; its value is them, written out.
    def webhooks? = key.end_with?(":webhooks")

    # The value as it is now is the truth, as this person says.
    def confirm(by:, value: self.value, note: self.note)
      update(value: value, note: note, confirmed_value: value.to_s.strip.presence, state: "confirmed",
        confirmed_by_name: by.display_name, confirmed_at: Time.current)
    end

    def mark_not_applicable(by:, note: self.note)
      update(note: note, state: "not_applicable", confirmed_by_name: by.display_name, confirmed_at: Time.current)
    end

    # Back to unconfirmed, forgetting who confirmed it.
    def reopen
      update(state: "unconfirmed", confirmed_value: nil, confirmed_by_name: nil, confirmed_at: nil)
    end

    # A person's change: a new value has to be confirmed again (what was confirmed stays, as "was").
    def revise(attributes)
      assign_revision(attributes)
      save
    end

    # A person saying what's true: the value (and any note) saved and confirmed as theirs, or
    # an empty value back to confirm. One save, so the history has it as one change.
    def record(attributes, by:)
      assign_revision(attributes)
      if value.present?
        assign_attributes(confirmed_value: value, state: "confirmed", confirmed_by_name: by.display_name, confirmed_at: Time.current)
      else
        assign_attributes(state: "unconfirmed", confirmed_value: nil, confirmed_by_name: nil, confirmed_at: nil)
      end
      save
    end

    def to_s = title

    # A file kept on the step (a conversion export, a screenshot of an approval, the brief), in the history too.
    def add_file(attachable)
      files.attach(attachable)
      touch
      audit "file added", { "files" => [ nil, files.attachments.last.filename.to_s ] }
    end

    def remove_file(attachment)
      attachment.purge_later
      touch
      audit "file removed", { "files" => [ attachment.filename.to_s, nil ] }
    end

    private
      def assign_revision(attributes)
        attributes = attributes.to_h.symbolize_keys
        if webhooks? && attributes.key?(:webhooks_attributes)
          self.webhooks_attributes = attributes[:webhooks_attributes]
          kept = webhooks.reject(&:marked_for_destruction?)
          kept.each_with_index { |webhook, index| webhook.position = index }
          self.value = kept.map(&:to_s).join("\n")
        end
        assign_attributes(attributes.slice(:value, :note, *(custom? ? %i[title detail] : [])))
        self.state = "unconfirmed" if value_changed? && !not_applicable?
      end

      def audit_account = account
      def audit_item_id = id
      def audit_value(field, value) = field == "state" ? STATE_LABELS[value] : super

      # A state change says what happened: confirmed, marked not applicable, reopened; a value
      # saved and confirmed at once was recorded.
      def audit_action(action, diff)
        return action unless action == "updated" && diff.key?("state")
        return diff["state"].last == "Confirmed" ? "recorded" : action if diff.key?("value")

        { "Confirmed" => "confirmed", "Not applicable" => "marked not applicable", "To do" => "reopened" }.fetch(diff["state"].last, action)
      end

      def blank_webhook?(attributes)
        attributes["id"].blank? && attributes["name"].blank? && attributes["url"].blank?
      end
  end
end
