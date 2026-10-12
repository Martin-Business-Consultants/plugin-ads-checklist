module AdsChecklist
  module Items
    class ConfirmationsController < ApplicationController
      allow_staff
      agent_tool :confirm_ad_account_item, on: :create, title: "Confirm an ad account checklist item",
        description: "Says the item's value is true, as you checked it: it's kept as what was confirmed, with your name and the time. value and note are recorded first when given.",
        params: { item: { value: "string", note: "string" } }, next_tools: %i[show_ad_account]
      agent_tool :reopen_ad_account_item, on: :destroy, title: "Reopen an ad account checklist item",
        description: "Undoes a confirmation or not applicable: the item is to confirm again."

      before_action :set_account, :set_item

      def create
        attributes = params.fetch(:item, {}).permit(:value, :note).to_h.symbolize_keys
        if @item.confirm(by: Current.user, **attributes)
          redirect_to ads_checklist_account_path(@account, item: @item.id), notice: "Confirmed “#{@item.title}”."
        else
          redirect_to ads_checklist_account_path(@account), alert: @item.errors.full_messages.to_sentence
        end
      end

      def destroy
        @item.reopen
        redirect_to ads_checklist_account_path(@account, item: @item.id), notice: "“#{@item.title}” is to confirm again."
      end
    end
  end
end
