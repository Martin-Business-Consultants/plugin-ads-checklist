module AdsChecklist
  module Recommendations
    class RejectionsController < ApplicationController
      allow_staff
      agent_tool :reject_ad_account_recommendation, on: :create, title: "Reject an AI audit's recommendation",
        description: "Leaves its checklist step as it is.", next_tools: %i[show_ad_account_ai_audit]

      before_action :set_account, :set_recommendation

      def create
        @recommendation.reject!(by: Current.user)
        redirect_to ads_checklist_account_scans_path(@account, rec: @recommendation.scan.pending.first&.id),
          notice: "Rejected the recommendation for “#{@recommendation.item.title}”."
      end
    end
  end
end
