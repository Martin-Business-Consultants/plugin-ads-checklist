module AdsChecklist
  module Items
    class NotApplicablesController < ApplicationController
      allow_staff
      agent_tool :mark_ad_account_item_not_applicable, on: :create, title: "Mark an ad account checklist item not applicable",
        description: "This account doesn't need it (an account with no forms has no form emails). It stops counting toward the checklist. note: why.",
        params: { item: { note: "string" } }, next_tools: %i[show_ad_account]

      before_action :set_account, :set_item

      def create
        @item.mark_not_applicable(by: Current.user, **params.fetch(:item, {}).permit(:note).to_h.symbolize_keys)
        redirect_to ads_checklist_account_path(@account, item: @item.id), notice: "“#{@item.title}” marked not applicable."
      end
    end
  end
end
