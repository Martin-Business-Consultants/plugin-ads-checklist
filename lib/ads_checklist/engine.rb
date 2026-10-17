module AdsChecklist
  # A Runwell plugin: it owns its tables (ads_checklist_*), points at core records by id, and
  # reaches the core only through the plugin contract (docs/plugin-contract.md in Runwell). Remove
  # it and Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as ads_checklist_*), so the core layout's helpers work
    # on the plugin's pages.
    initializer "ads_checklist.routes" do |app|
      app.routes.append do
        scope module: "ads_checklist", as: "ads_checklist" do
          resources :audits, only: :index, path: "ads/history"
          resources :accounts, path: "ads" do
            resources :scans, only: %i[index create]
            resources :todos, only: :create
            resources :recommendations, only: [] do
              resource :approval, only: :create, controller: "recommendations/approvals"
              resource :rejection, only: :create, controller: "recommendations/rejections"
            end
            resources :items, only: %i[create edit update destroy] do
              resources :files, only: %i[create destroy], controller: "items/files"
              resource :confirmation, only: %i[create destroy], controller: "items/confirmations"
              resource :not_applicable, only: :create, controller: "items/not_applicables"
            end
          end
        end
      end
    end

    initializer "ads_checklist.helpers" do
      ActiveSupport.on_load(:action_view) { include AdsChecklist::AccountsHelper }
    end

    # A client's ad accounts. Never a column on clients.
    initializer "ads_checklist.models" do
      ActiveSupport.on_load(:runwell_client) do
        has_many :ads_checklist_accounts, class_name: "AdsChecklist::Account", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :ads_checklist, name: "Ads", version: AdsChecklist::VERSION,
        author: "Martin Business Consultants", enabled_by_default: false, requires: ">= 2.29.0",
        homepage: "https://github.com/Martin-Business-Consultants/plugin-ads-checklist",
        description: "Every client's Google Ads and Meta Ads accounts, each with a step-by-step checklist to take it " \
                     "live: access and billing first, then tracking, the campaigns, launch and after launch, each " \
                     "recorded and confirmed by a person."
      # icon: arrived in Runwell 2.25; an older core would refuse it and fail to boot.
      nav_icon = Runwell::Plugins.method(:nav).parameters.any? { |_, name| name == :icon } ? { icon: "megaphone" } : {}
      Runwell::Plugins.nav :ads_checklist, "Ads", -> { ads_checklist_accounts_path }, **nav_icon
      Runwell::Plugins.permission :ads_checklist, :manage_ad_accounts, name: "Add, change and delete ad accounts", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :ads_checklist, "ads_checklist/ads_checklist"
      Runwell::Plugins.slot :client_panel, :ads_checklist, "ads_checklist/slots/client_panel"
      Runwell::Plugins.agent_workflow :ads_checklist, "Taking a client's ad account live", <<~STEPS
        1. `list_ad_accounts` (show: attention) for the accounts with steps still to do; `show_ad_account` for one's checklist, in order, with how to do each step and its next_step. Each account is Google Ads or Meta Ads, with its own steps.
        2. Work down the steps in order: access and billing first (the account, our manager or partner access, Analytics, Tag Manager, the website), then tracking, since nothing should spend before conversions are measured; then the campaigns, launch and after launch.
        3. `update_ad_account_item` to record what's true (whose account, what we can do, the IDs): saving a value confirms it as yours. The lead webhooks step takes webhooks_attributes (name, url, pairs). `mark_ad_account_item_not_applicable` for what the account doesn't need.
        4. What only the client can do (adding us to an account, approving ads, the budget, sign-off to launch) goes to them as a question; never record a password, card number or secret, only where it's kept.
      STEPS
    end
  end
end
