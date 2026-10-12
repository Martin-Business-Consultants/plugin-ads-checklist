module AdsChecklist
  # An AI audit of an ad account's website. Account::Probe finds out what it can from outside (the
  # domain's verifications, the landing page's tags, the Tag Manager container); the install's AI
  # (the AI plugin's Ai.structured) turns that into a Recommendation per step it says something
  # about, which a person approves, changes or rejects. Run in ScanJob.
  class Scan < ApplicationRecord
    STATES = %w[queued running ready failed].freeze
    STUCK_AFTER = 10.minutes
    CONFIDENCES = %w[high medium low].freeze

    belongs_to :account
    belongs_to :user
    has_many :recommendations, -> { order(:position, :id) }, dependent: :delete_all, inverse_of: :scan
    has_many_attached :files

    serialize :facts, coder: JSON, type: Hash

    normalizes :domain, with: ->(domain) { Account::Probe.normalize(domain) }

    validates :domain, presence: true, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/, message: "isn't a domain like example.com" }
    validates :state, inclusion: { in: STATES }

    scope :latest_first, -> { order(id: :desc) }

    # Whether the install's AI can run one for this account (the AI plugin, on, set up, within budget).
    def self.ai_available_for?(account)
      defined?(::Ai) && ::Ai.respond_to?(:structured) && ::Ai.available_for?(account)
    end

    def working? = state.in?(%w[queued running]) && updated_at > STUCK_AFTER.ago
    def ready? = state == "ready"
    def failed? = state == "failed" || (state.in?(%w[queued running]) && !working?)
    def pending = recommendations.select { it.state == "pending" }

    def run_later = ScanJob.perform_later(self)

    # Called by ScanJob. Never raises: what went wrong is kept in `error`.
    def run!
      update!(state: "running", started_at: Time.current)
      probe = Account::Probe.new(domain, page: account.url)
      update!(facts: probe.facts)
      probe.files.each { |name, (body, type)| files.attach(io: StringIO.new(body), filename: name, content_type: type) }

      answer = ::Ai.structured(user: user, name: "ad_account_audit", schema: schema, instructions: instructions, prompt: prompt)
      add_recommendations(Array(answer["recommendations"]))
      update!(state: "ready", finished_at: Time.current)
    rescue => error
      Rails.logger.error("[ads_checklist] AI audit #{id}: #{error.class}: #{error.message}")
      update_columns(state: "failed", error: "#{error.class.name.demodulize}: #{error.message}".truncate(500), finished_at: Time.current, updated_at: Time.current)
    end

    private
      def steps = @steps ||= account.items.to_a

      def add_recommendations(answers)
        by_key = steps.index_by(&:key)
        answers.each_with_index do |answer, index|
          item = by_key[answer["item_key"]] or next
          value = answer["value"].to_s.strip.presence or next
          next if item.confirmed? && item.value.to_s == value

          recommendations.create!(item: item, value: value, note: answer["note"].to_s.strip.presence,
            evidence: answer["evidence"].to_s.strip.presence, confidence: answer["confidence"].presence_in(CONFIDENCES),
            position: by_key.keys.index(item.key) || index)
        end
      end

      def schema
        { type: "object", additionalProperties: false, required: %w[recommendations], properties: {
          recommendations: { type: "array", items: { type: "object", additionalProperties: false,
            required: %w[item_key value note evidence confidence],
            properties: {
              item_key: { type: "string", enum: steps.map(&:key) },
              value: { type: "string", description: "What to record on the step, as a person would write it: short and specific." },
              note: { type: "string", description: "What's still to do or check, or \"\"." },
              evidence: { type: "string", description: "The fact it comes from (\"RDAP registrar\", \"MX records\")." },
              confidence: { type: "string", enum: CONFIDENCES }
            } } }
        } }
      end

      def instructions
        <<~TEXT
          You help a team take a client's #{account.platform_name} account live. They keep a checklist of steps to gather and record: access to the account and the tools around it, billing, tracking (the tags and conversions), the campaigns, the launch and what follows. You are given facts found about the website the ads send people to, from outside, without logging in anywhere: the domain's verifications in DNS, how its addresses answer, the tags on its landing page (the Google tag and conversion IDs, Analytics, Tag Manager, the Meta Pixel and its events, consent banners, phone links, forms) and what its public Tag Manager container loads.

          For each step the facts say something about, recommend what to record on it.
          - Only what the facts show. Never invent an account, a person, a date, a budget or access. A tag on the page shows the tag is installed, not who owns the account or that we can get in: say what the facts show in value, and put what's still to do in note ("Ask the client to add us as Admin").
          - A tag that's missing is worth saying too, when the step is about it ("No Meta Pixel found on the landing page or in GTM-ABC123"), with low confidence, since it may load another way.
          - value is short and specific, in the step's own words: IDs, names, addresses, dates (as 3 Mar 2027).
          - evidence names the fact it comes from. confidence: high when a fact states it, medium when it's inferred, low when it's a guess worth checking.
          - At most one recommendation per step; skip steps the facts say nothing about, and steps whose current value already says the same.
          - Write plainly, for anyone running a business: no jargon you don't need.
          Today is #{Date.current.to_fs(:long)}.
        TEXT
      end

      def prompt
        lines = steps.map do |item|
          "- #{item.key} | #{item.title} | #{item.detail} | now: #{item.value.presence || "nothing"} (#{item.state_label.downcase})"
        end
        "#{account.platform_name} account: #{account.name}#{" (#{account.external_id_label} #{account.external_id})" if account.external_id}\n" \
          "Domain: #{domain}\n\nThe checklist's steps (key | title | what it records | what's recorded now):\n#{lines.join("\n")}\n\n" \
          "Facts found about the domain (JSON):\n#{JSON.pretty_generate(facts)}"
      end
  end
end
