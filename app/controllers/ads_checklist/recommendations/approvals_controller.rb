module AdsChecklist
  module Recommendations
    class ApprovalsController < ApplicationController
      allow_staff
      agent_tool :approve_ad_account_recommendation, on: :create, title: "Approve an AI audit's recommendation",
        description: "Records the recommendation on its checklist step as yours (confirmed, in the history), with value and note changed first when given.",
        params: { recommendation: { value: "string", note: "string" } }, next_tools: %i[show_ad_account_ai_audit]

      before_action :set_account, :set_recommendation

      def create
        attributes = params.fetch(:recommendation, {}).permit(:value, :note).to_h.symbolize_keys
        if @recommendation.approve!(by: Current.user, **attributes)
          redirect_to ads_checklist_account_scans_path(@account, rec: @recommendation.scan.pending.first&.id),
            notice: "Recorded on “#{@recommendation.item.title}”."
        else
          redirect_to ads_checklist_account_scans_path(@account, rec: @recommendation.id),
            alert: (@recommendation.errors.full_messages + @recommendation.item.errors.full_messages).to_sentence.presence || "Couldn't record it."
        end
      end
    end
  end
end
