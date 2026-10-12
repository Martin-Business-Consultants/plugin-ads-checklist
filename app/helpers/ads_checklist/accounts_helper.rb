module AdsChecklist
  module AccountsHelper
    ITEM_TONES = { "unconfirmed" => "waiting", "confirmed" => "positive", "not_applicable" => "neutral" }.freeze

    # An item's state, tinted like the core's status tags.
    def ad_account_item_state_tag(item)
      tag.span item.state_label, class: "status-tag status-tag--#{ITEM_TONES.fetch(item.state)} txt-nowrap"
    end

    # Google Ads or Meta Ads, in the platform's colour.
    def ad_platform_tag(account)
      tag.span account.platform_name, class: "status-tag ads-checklist-platform ads-checklist-platform--#{account.platform} txt-nowrap"
    end

    def ad_platform_options = Account::PLATFORMS.invert.to_a

    # An account's checklist in a few words: confirmed of total.
    def ad_account_summary_tag(account, summary = account.summary)
      tag.span summary.to_s, class: "status-tag status-tag--#{summary.ready? ? "positive" : "waiting"} txt-nowrap"
    end

    # "4 to do", or nil when every step is done.
    def ad_account_attention_text(account, summary = account.summary)
      "#{summary.unconfirmed} to do" if summary.unconfirmed.positive?
    end

    # [[group, items], …] in the checklist's order (Item::GROUPS, then any other group).
    def ad_account_item_groups(items)
      grouped = items.group_by(&:group)
      (Item::GROUPS & grouped.keys).map { [ it, grouped[it] ] } + (grouped.keys - Item::GROUPS).map { [ it, grouped[it] ] }
    end

    # The items as the page lists them, each with its step number: { item => 1, … }.
    def ad_account_step_numbers(items)
      ad_account_item_groups(items).flat_map(&:last).each_with_index.to_h { |item, index| [ item, index + 1 ] }
    end

    # A group's items in a few words, beside its heading: "3 of 4 done".
    def ad_account_group_summary(items)
      applicable = items.reject(&:not_applicable?)
      "#{applicable.count(&:confirmed?)} of #{applicable.size} done"
    end

    # Every step in the group that applies is confirmed.
    def ad_account_group_done?(items)
      applicable = items.reject(&:not_applicable?)
      applicable.any? && applicable.all?(&:confirmed?)
    end

    # A step's state in the list: a dot, lit green and glowing once confirmed.
    def ad_account_item_marker(item)
      tag.span class: "ads-checklist-dot ads-checklist-dot--#{item.state}", title: item.state_label
    end

    def ad_account_client_options = Client.ordered.pluck(:name, :id)

    # The Webhooks step's fields, inside the item's form: a repeater (the core's `repeater`
    # controller) of webhooks, each an accordion with its name, address and keys and values.
    # Built here rather than in partials, which can't render inside form_with.
    def ad_account_webhooks_fields(form, item)
      rows = item.webhooks.each_with_index.map { |webhook, index| ad_account_webhook_row(form, webhook, index) }
      tag.div class: "ads-checklist-webhooks", data: { controller: "repeater", repeater_placeholder_value: "NEW_WEBHOOK" } do
        safe_join([
          hidden_field_tag("#{form.object_name}[webhooks_attributes][-1][name]", "", id: nil),
          tag.div(safe_join(rows), class: "ads-checklist-webhooks__list", data: { repeater_target: "list" }),
          tag.template(ad_account_webhook_row(form, Webhook.new, "NEW_WEBHOOK", open: true), data: { repeater_target: "template" }),
          tag.div(class: "section-actions") do
            tag.button(safe_join([ icon_tag("add"), tag.span("Add a webhook") ], " "), type: "button", class: "btn txt-small", data: { action: "repeater#add" })
          end
        ])
      end
    end

    private
      def ad_account_webhook_row(form, webhook, index, open: false)
        form.fields_for :webhooks, webhook, child_index: index, include_id: false do |fields|
          tag.details class: "ads-checklist-webhook", open: open, data: { repeater_row: true } do
            safe_join([
              tag.summary(class: "ads-checklist-webhook__summary") do
                safe_join([
                  icon_tag("caret-down", class: "ads-checklist-webhook__caret"),
                  tag.strong(webhook.name || "New webhook", class: "overflow-ellipsis"),
                  tag.span(webhook.url, class: "txt-x-small txt-subtle overflow-ellipsis")
                ])
              end,
              tag.div(class: "ads-checklist-webhook__body") do
                safe_join([
                  (fields.hidden_field(:id) if webhook.persisted?),
                  (fields.hidden_field(:_destroy, value: "0") if webhook.persisted?),
                  tag.label(class: "record-form__field") do
                    safe_join([ tag.span("Name", class: "record-form__label"),
                      fields.text_field(:name, class: "input full-width", autocomplete: "off", placeholder: "Zapier to the CRM") ])
                  end,
                  tag.label(class: "record-form__field") do
                    safe_join([ tag.span("Webhook URL", class: "record-form__label"),
                      fields.url_field(:url, class: "input full-width", autocomplete: "off", placeholder: "https://hooks.zapier.com/hooks/catch/…") ])
                  end,
                  ad_account_pairs_fields(fields, webhook),
                  tag.div(class: "section-actions") do
                    tag.button(safe_join([ icon_tag("trash"), tag.span("Remove this webhook") ], " "), type: "button",
                      class: "btn txt-small", data: { action: "repeater#remove" })
                  end
                ].compact)
              end
            ])
          end
        end
      end

      # A webhook's keys and values: a repeater of its own, nested in the webhook's.
      def ad_account_pairs_fields(fields, webhook)
        name = "#{fields.object_name}[pairs]"
        rows = webhook.pairs.each_with_index.map { |pair, index| ad_account_pair_row(name, pair, index) }
        tag.div class: "record-form__field", data: { controller: "repeater", repeater_placeholder_value: "NEW_PAIR" } do
          safe_join([
            tag.span("Keys and values", class: "record-form__label"),
            hidden_field_tag("#{name}[-1][key]", "", id: nil),
            tag.div(safe_join(rows), class: "ads-checklist-pairs", data: { repeater_target: "list" }),
            tag.template(ad_account_pair_row(name, {}, "NEW_PAIR"), data: { repeater_target: "template" }),
            tag.div do
              tag.button(safe_join([ icon_tag("add"), tag.span("Add a key") ], " "), type: "button", class: "btn txt-small", data: { action: "repeater#add" })
            end
          ])
        end
      end

      def ad_account_pair_row(name, pair, index)
        tag.div class: "ads-checklist-pair", data: { repeater_row: true } do
          safe_join([
            text_field_tag("#{name}[#{index}][key]", pair["key"], id: nil, class: "input", autocomplete: "off", placeholder: "Key", aria: { label: "Key" }),
            text_field_tag("#{name}[#{index}][value]", pair["value"], id: nil, class: "input", autocomplete: "off", placeholder: "Value", aria: { label: "Value" }),
            tag.button(safe_join([ icon_tag("close"), tag.span("Remove", class: "for-screen-reader") ]), type: "button",
              class: "btn btn--circle borderless txt-small", title: "Remove", data: { action: "repeater#remove" })
          ])
        end
      end
  end
end
