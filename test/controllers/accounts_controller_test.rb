require_relative "../test_helper"

module AdsChecklist
  class AccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Setting.current.toggle_plugin!(:ads_checklist, enabled: true)
      @account = Account.create!(client: clients(:acme), platform: "google", name: "Acme account", url: "https://acme.example")
      sign_in_as users(:sarah)
    end

    test "404 while the plugin is off" do
      Setting.current.toggle_plugin!(:ads_checklist, enabled: false)

      get ads_checklist_accounts_path
      assert_response :not_found
    end

    test "the index shows what needs attention, and all" do
      done = Account.create!(client: clients(:globex), platform: "google", name: "Globex account")
      done.items.each { it.confirm(by: users(:ted), value: "yes") }

      get ads_checklist_accounts_path
      assert_response :success
      assert_includes response.body, "Acme account"
      assert_not_includes response.body, "Globex account"

      get ads_checklist_accounts_path(show: "all")
      assert_includes response.body, "Globex account"
    end

    test "the index as JSON, for agents" do
      get ads_checklist_accounts_path(format: :json, show: "all")

      body = response.parsed_body
      assert_equal "1 ad account", body["summary"]
      assert_equal "Acme account", body["accounts"].first["name"]
      assert_equal 0, body["accounts"].first["checklist"]["confirmed"]
      assert_equal "Acme Co", body["accounts"].first["client"]["display_name"]
    end

    test "an ad account's checklist, page and JSON" do
      get ads_checklist_account_path(@account)
      assert_response :success
      assert_includes response.body, "Google Ads account"
      assert_includes response.body, "Conversion actions"
      assert_select "#ads_checklist_detail", 1
      assert_select "aside.settings__panel--side", 0
      assert_select "nav.scope-nav a[aria-current='page']", 1
      assert_select "#ads_checklist_detail input[name='item[value]']"
      assert_select "#ads_checklist_detail textarea[name='item[note]']"
      assert_select "form[action$='/confirmation']", count: 0
      assert_select "form[action$='/not_applicable']", 1

      item = @account.items.find_by!(key: "google:tracking:conversions")
      get ads_checklist_account_path(@account, item: item.id)
      assert_select "a#link_ads_checklist_item_#{item.id}[aria-current='page']"
      assert_select "#ads_checklist_detail h2", item.title

      get ads_checklist_account_path(@account, format: :json)
      body = response.parsed_body
      assert_match "Acme account: 0 of #{Account::Defaults::GOOGLE.size} confirmed", body["summary"]
      assert_equal Account::Defaults::GOOGLE.size, body["items"].size
      assert_equal "AdsChecklist::Account", body["type"]
    end

    test "adding an ad account, with its platform's checklist" do
      post ads_checklist_accounts_path, params: { account: { client_id: clients(:globex).id, platform: "meta", name: "Globex", external_id: "act_123", url: "https://globex.example" } }
      account = Account.find_by!(name: "Globex")
      assert_redirected_to ads_checklist_account_path(account)
      assert_equal clients(:globex), account.client
      assert_equal "meta:access:business_portfolio", account.next_item.key
      assert_equal Account::Defaults::META.size, account.items.count

      patch ads_checklist_account_path(account), params: { account: { platform: "google", name: "Globex Meta" } }
      assert_equal "meta", account.reload.platform
      assert_equal "Globex Meta", account.name
    end

    test "the form and its errors" do
      get new_ads_checklist_account_path(client_id: clients(:acme).id)
      assert_response :success

      post ads_checklist_accounts_path, params: { account: { client_id: clients(:acme).id, name: "" } }
      assert_response :unprocessable_entity

      post ads_checklist_accounts_path, params: { account: { client_id: clients(:acme).id, name: "No platform" } }
      assert_response :unprocessable_entity
    end

    test "editing and deleting" do
      get edit_ads_checklist_account_path(@account)
      assert_response :success

      patch ads_checklist_account_path(@account), params: { account: { name: "Acme main account" } }
      assert_equal "Acme main account", @account.reload.name

      delete ads_checklist_account_path(@account)
      assert_redirected_to ads_checklist_accounts_path
      assert_not Account.exists?(@account.id)
    end

    test "only owners and managers add, change and delete ad accounts" do
      member = User.create!(email_address: "member@example.com", name: "Mo Member", role: "member", password: "password")
      sign_in_as member

      get ads_checklist_account_path(@account)
      assert_response :success
      delete ads_checklist_account_path(@account)
      assert Account.exists?(@account.id)
    end

    test "the client's Ads tab" do
      get client_path(clients(:acme), tab: "plugin-ads_checklist")
      assert_response :success
      assert_includes response.body, "Acme account"
      assert_includes response.body, new_ads_checklist_account_path(client_id: clients(:acme).id)
    end
  end
end
