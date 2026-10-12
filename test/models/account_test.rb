require_relative "../test_helper"

module AdsChecklist
  class AccountTest < ActiveSupport::TestCase
    setup { @client = clients(:acme) }

    test "a new account starts with the standard checklist, once" do
      account = Account.create!(client: @client, platform: "google", name: "Main account", url: "https://acme.example/")

      assert_equal Account::Defaults::GOOGLE.size, account.items.count
      assert_equal "https://acme.example", account.url
      assert account.items.all? { it.state == "unconfirmed" }
      assert_equal "google:access:account", account.next_item.key
      account.apply_standard_checklist
      assert_equal Account::Defaults::GOOGLE.size, account.items.count
      assert_equal account, @client.ads_checklist_accounts.first
    end

    test "addresses need a scheme" do
      account = Account.new(client: @client, platform: "google", name: "Main", url: "acme.example")

      assert_not account.valid?
      assert account.errors[:url].any?
    end

    test "the summary counts what applies and is ready when all of it is confirmed without problems" do
      account = Account.create!(client: @client, platform: "google", name: "Main")
      ted = users(:ted)

      assert_not account.summary.ready?
      account.items.each { it.key == "google:access:merchant_center" ? it.mark_not_applicable(by: ted) : it.confirm(by: ted, value: "yes") }
      summary = account.reload.summary

      assert_equal Account::Defaults::GOOGLE.size - 1, summary.total
      assert_equal 1, summary.not_applicable
      assert summary.ready?
      assert_not account.needs_attention?
    end
  end
end
