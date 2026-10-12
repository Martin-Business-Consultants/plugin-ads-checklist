module AdsChecklist
  # The AI audit sheet on an account's page: the domain to audit, the latest audit, and its
  # recommendations beside the one picked (rec=), each to approve, change or reject.
  class ScansController < ApplicationController
    allow_staff only: :index
    require_permission :manage_ad_accounts, only: :create
    agent_tool :show_ad_account_ai_audit, on: :index, title: "Show an ad account's AI audit",
      description: "The latest AI audit of an ad account: whether it's still running, what was found about its website (verifications, the landing page's tags, the Tag Manager container), and each recommendation for a checklist step (value, note, evidence, confidence) with whether it's pending, approved or rejected.",
      next_tools: %i[approve_ad_account_recommendation reject_ad_account_recommendation]
    agent_tool :audit_ad_account_with_ai, on: :create, title: "Run an AI audit of an ad account",
      description: "Reads the website the ads send people to from outside (the domain's Google and Meta verifications, the landing page's Google tag, conversion IDs, Analytics, Tag Manager, Meta Pixel and events, consent banner, and what the Tag Manager container loads) and has the install's AI recommend values for the checklist's steps, in the background (a minute or so). Needs the AI plugin on. Nothing is recorded until a person approves each recommendation.",
      params: { scan: { domain: "string!" } }, next_tools: %i[show_ad_account_ai_audit]

    before_action :set_account

    def index
      @ai = Scan.ai_available_for?(@account)
      @scan = @account.scans.latest_first.includes(recommendations: :item).first
      @recommendation = @scan&.recommendations&.find { it.id.to_s == params[:rec].to_s } || @scan&.pending&.first || @scan&.recommendations&.first
    end

    def create
      return redirect_to(ads_checklist_account_scans_path(@account), alert: "AI audits need the AI plugin on, set up and within its budget.") unless Scan.ai_available_for?(@account)

      scan = @account.scans.new(user: Current.user, domain: params.expect(scan: [ :domain ])[:domain])
      if scan.save
        scan.run_later
        redirect_to ads_checklist_account_scans_path(@account), notice: "Auditing #{scan.domain}: it takes a minute or so."
      else
        redirect_to ads_checklist_account_scans_path(@account), alert: scan.errors.full_messages.to_sentence
      end
    end
  end
end
