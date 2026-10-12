require_relative "../test_helper"

module AdsChecklist
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Setting.current.toggle_plugin!(:ads_checklist, enabled: true)
      @account = Account.create!(client: clients(:acme), platform: "google", name: "Acme account")
      @item = @account.items.find_by!(key: "google:tracking:conversions")
      sign_in_as users(:sarah)
    end

    test "saving a value confirms it as the saver's; emptying it is to confirm again" do
      get edit_ads_checklist_account_item_path(@account, @item)
      assert_response :success

      patch ads_checklist_account_item_path(@account, @item), params: { item: { value: "ann@acme.example; cc bob@acme.example" } }
      assert_redirected_to ads_checklist_account_path(@account, item: @item.id)
      @item.reload
      assert_equal "confirmed", @item.state
      assert_equal "Sarah Staff", @item.confirmed_by_name
      assert_equal "ann@acme.example; cc bob@acme.example", @item.confirmed_value

      patch ads_checklist_account_item_path(@account, @item), params: { item: { value: "" } }
      assert_equal "unconfirmed", @item.reload.state
      assert_nil @item.confirmed_value
    end

    test "saving on the account's page sends back the item and its row" do
      patch ads_checklist_account_item_path(@account, @item), params: { item: { value: "ann@acme.example" } }, as: :turbo_stream
      assert_response :success
      assert_match %(<turbo-stream action="update" target="ads_checklist_detail">), response.body
      assert_match %(<turbo-stream action="replace" target="link_ads_checklist_item_#{@item.id}">), response.body
      assert_match "Confirmed", response.body
      assert_match %(target="group_tracking_ads_checklist_account_#{@account.id}"), response.body
      assert_match "1 of #{Account::Defaults::GOOGLE.count { it[:group] == "Tracking" }} done", response.body
      assert_match %(<turbo-stream action="replace" target="checklist_summary_ads_checklist_account_#{@account.id}">), response.body
      assert_match "#{Account::Defaults::GOOGLE.size - 1} to do", response.body
      assert_match "ann@acme.example", response.body
    end

    test "a note alone saves without confirming" do
      patch ads_checklist_account_item_path(@account, @item), params: { item: { note: "As Ann asked" } }, as: :turbo_stream
      assert_response :success
      assert_equal "As Ann asked", @item.reload.note
      assert_equal "unconfirmed", @item.state
    end

    test "confirm with a value in one go, then reopen" do
      post ads_checklist_account_item_confirmation_path(@account, @item), params: { item: { value: "ann@acme.example" } }
      assert_equal "ann@acme.example", @item.reload.confirmed_value

      delete ads_checklist_account_item_confirmation_path(@account, @item)
      assert_equal "unconfirmed", @item.reload.state
    end

    test "not applicable" do
      post ads_checklist_account_item_not_applicable_path(@account, @item), params: { item: { note: "No forms" } }
      assert_equal "not_applicable", @item.reload.state
      assert_equal "No forms", @item.note
    end

    test "custom items are added and removed; standard ones can't be removed" do
      post ads_checklist_account_items_path(@account), params: { item: { title: "Cookie banner", value: "Cookiebot" } }
      custom = @account.items.find_by!(title: "Cookie banner")
      assert_equal "Custom", custom.group

      delete ads_checklist_account_item_path(@account, @item)
      assert @account.items.exists?(@item.id)
      assert_match "not applicable", flash[:alert]

      delete ads_checklist_account_item_path(@account, custom)
      assert_not @account.items.exists?(custom.id)
    end

    test "an item that belongs to another account is not found" do
      other = Account.create!(client: clients(:globex), platform: "google", name: "Other")

      post ads_checklist_account_item_confirmation_path(other, @item)
      assert_response :not_found
    end
  end
end
