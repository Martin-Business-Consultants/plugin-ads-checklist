module AdsChecklist
  # Work made from an ad account's page: a core todo on one of the account's client's engagements,
  # linked to the account and the step it's about, whose description links back to that step.
  class TodosController < ApplicationController
    allow_staff
    agent_tool :add_ad_account_work, on: :create, title: "Add work from an ad account's checklist",
      description: "A todo on one of the ad account's client's engagements (engagement_id), about one of its checklist steps (item_id, optional): it shows on that step, and its description links back to it. owner_id leads it; other_owner_ids are also on it.",
      params: { todo: { engagement_id: "integer!", item_id: "integer", title: "string!", description: "text", owner_id: "integer", due_on: "date", other_owner_ids: "integer[]" } },
      next_tools: %i[show_ad_account]

    before_action :set_account

    def create
      attributes = params.expect(todo: [ :engagement_id, :item_id, :title, :description, :owner_id, :due_on, other_owner_ids: [] ])
      engagement = @account.client.engagements.open.find_by(id: attributes[:engagement_id])
      item = @account.items.find_by(id: attributes[:item_id]) if attributes[:item_id].present?
      back = ads_checklist_account_path(@account, item: item&.id)
      return redirect_to(back, alert: "Choose one of #{@account.client.name}'s open #{helpers.term(:engagement, count: 2).downcase}.") unless engagement

      todo = engagement.todos.new(attributes.except(:engagement_id, :item_id).merge(created_by: Current.user, description: description_for(attributes[:description], item)))
      if todo.save
        todo.record_event!("todo.created")
        @account.todo_links.create!(item: item, todo: todo)
        redirect_to back, notice: "Added “#{todo.title}” to #{engagement.ref} #{engagement.title}."
      else
        redirect_to back, alert: todo.errors.full_messages.to_sentence
      end
    end

    private
      # The person's details, then where it came from: the step on the ad account's page.
      def description_for(text, item)
        source = helpers.link_to([ @account.name, item&.title ].compact.join(" · "), ads_checklist_account_url(@account, item: item&.id))
        [ text.presence, "<p>From the ad account checklist: #{source}</p>" ].compact.join
      end
  end
end
