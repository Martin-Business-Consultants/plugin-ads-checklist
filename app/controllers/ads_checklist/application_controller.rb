module AdsChecklist
  # The plugin's pages use the core's layout, and vanish while it's switched off.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:ads_checklist) }

    private
      def set_account = @account = Account.find(params[:account_id] || params[:id])
      def set_item = @item = @account.items.find(params[:item_id] || params[:id])
      def set_recommendation = @recommendation = Recommendation.joins(:scan).where(scan: { account_id: @account.id }).find(params[:recommendation_id])
  end
end
