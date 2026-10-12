module AdsChecklist
  class AccountsController < ApplicationController
    SHOW = %w[attention all].freeze

    allow_staff only: %i[index show]
    require_permission :manage_ad_accounts, except: %i[index show]
    agent_tool :list_ad_accounts, on: :index, title: "List ad accounts",
      description: "Every client's Google Ads and Meta Ads accounts with how much of each checklist is confirmed. show: attention (the default: a step still to do) or all. platform: google or meta. client_id: one client's.",
      params: { show: SHOW, platform: Account::PLATFORMS.keys, client_id: "integer" }, next_tools: %i[show_ad_account create_ad_account]
    agent_tool :show_ad_account, on: :show, title: "Show an ad account's checklist",
      description: "An ad account and its go-live checklist, in order: each step's value, whether it's confirmed (and who confirmed it, when) or not applicable, and how to do it. next_step is the first one still to do.",
      next_tools: %i[update_ad_account_item confirm_ad_account_item mark_ad_account_item_not_applicable]
    agent_tool :create_ad_account, on: :create, title: "Add an ad account",
      description: "A client's Google Ads (platform google) or Meta Ads (meta) account, with that platform's go-live checklist: access, billing, tracking, campaigns, launch, after launch. external_id: the customer ID (Google, 123-456-7890) or ad account ID (Meta, act_…). url: the website the ads send people to. The platform can't change later.",
      params: { account: { client_id: "integer!", platform: Account::PLATFORMS.keys, name: "string!", external_id: "string", url: "string" } },
      next_tools: %i[show_ad_account]
    agent_tool :update_ad_account, on: :update, title: "Change an ad account",
      description: "Its name, customer or ad account ID, or website. Not its platform.",
      params: { account: { name: "string", external_id: "string", url: "string" } }
    agent_tool :delete_ad_account, on: :destroy, title: "Delete an ad account", description: "Forgets the ad account and its checklist."

    before_action :set_account, only: %i[show edit update destroy]

    def index
      @show = params[:show].presence_in(SHOW) || "attention"
      @platform = params[:platform].presence_in(Account::PLATFORMS.keys)
      @client = Client.find(params[:client_id]) if params[:client_id].present?
      accounts = Account.ordered.includes(:client, :items)
      accounts = accounts.where(client: @client) if @client
      accounts = accounts.where(platform: @platform) if @platform
      @accounts = @show == "attention" ? accounts.select(&:needs_attention?) : accounts.to_a
      @counts = { "attention" => accounts.count(&:needs_attention?), "all" => accounts.size }
    end

    def show
      @items = @account.items.with_attached_files.to_a
      @item = @items.find { it.id.to_s == params[:item].to_s } || @account.next_item || @items.first
    end

    def new
      @account = Account.new(client_id: params[:client_id], platform: params[:platform].presence_in(Account::PLATFORMS.keys))
    end

    def create
      @account = Account.new(account_params)
      if @account.save
        redirect_to ads_checklist_account_path(@account), notice: "#{@account.name} added, with the #{@account.platform_name} go-live checklist."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @account.revise(account_params.except(:client_id, :platform))
        redirect_to ads_checklist_account_path(@account), notice: "#{@account.name} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @account.destroy!
      redirect_to ads_checklist_accounts_path, notice: "#{@account.name} deleted, with its checklist."
    end

    private
      def account_params = params.expect(account: %i[client_id platform name external_id url])
  end
end
