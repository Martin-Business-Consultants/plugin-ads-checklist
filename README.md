# Ads for Runwell

Every client's Google Ads and Meta Ads accounts, each with a step-by-step checklist to take it live:
the place to gather and record everything a launch needs, in the order to get it. Access and
billing come first, then tracking (nothing should spend before conversions are measured), the
campaigns, the launch itself, and what follows it. It mirrors the Websites plugin
(`plugin-website-checklist`), screen for screen.

A Runwell plugin (Runwell's `docs/plugins.md`): a Rails engine that owns its `ads_checklist_*`
tables, reaches clients by id, and extends the core only through the plugin contract. Needs
Runwell 2.24 or newer (2.25 for its megaphone in the nav).

## Install

Settings › Plugins › Install, with `Martin-Business-Consultants/plugin-ads-checklist`, or from
the shell:

    bin/rails "plugins:install[Martin-Business-Consultants/plugin-ads-checklist]"

Then switch it on in Settings › Plugins. Remove deletes its code and keeps its tables.

## What it does

- **Ads**, in the nav (a megaphone): every client's accounts, those with steps still to do first,
  filtered by platform, and an **Ads** tab on each client.
- **An account is Google Ads or Meta Ads**, chosen when it's added (it decides the steps, so it
  doesn't change later), with its customer ID or ad account ID and the website the ads send people to.
- **The go-live checklist**, numbered, in the order to work through it. For Google Ads:
  1. Access: the Google Ads account, linked to our manager account, Analytics, Tag Manager, the
     website, Merchant Center, the Business Profile
  2. Billing: payment in the client's name, the budget agreed
  3. Tracking: the Google tag, conversion actions, enhanced conversions, Analytics linked and
     auto-tagging, consent, calls, leads back from the CRM, lead form webhooks, a test conversion
  4. Campaigns: goals and targets, locations and schedule, keywords and negatives, campaigns and
     bidding, ads and assets approved by the client, landing pages, audiences
  5. Launch: ads approved and advertiser verified, the client's sign-off, campaigns live
  6. After launch: conversions arriving, the first search terms review, reporting, alerts

  For Meta Ads:
  1. Access: the business portfolio, our business added as a partner, the ad account (its currency
     and time zone), the Facebook Page, Instagram, the website
  2. Billing: payment in the client's name, the budget agreed
  3. Tracking: the domain verified, the Meta Pixel, conversion events, the Conversions API,
     consent, test events, lead ads to the CRM (webhooks)
  4. Campaigns: goals and targets, the special ad category, audiences, campaigns and placements,
     creative approved by the client, instant forms, URL parameters
  5. Launch: ads approved, the client's sign-off, campaigns live
  6. After launch: events arriving, the first performance review, reporting, alerts

  And Custom: anything else the team adds.
- **A list and the step beside it**: the steps on the left, each with a dot for its state; pick
  one and it opens on the right with what it's for, how to do it, and an example of what to
  record. Saving a value confirms it as yours (your name and the time are kept), and emptying it
  puts it back to do. A step the account doesn't need is marked so, and Next goes on to the
  following step. The page opens on the first step still to do.
- **Lead webhooks** (lead form assets, lead ads) are recorded one by one, each folding open: its name, its URL, and the keys and
  values it's set up with (add and remove rows as you go).
- **Files** on every step, beside its note, in a drop box: drop files on it or choose them (a
  conversions export, the brief, a screenshot of an approval).
- **Work** from the ad account's page: the button opens a sheet on the right to add a todo on one of
  the client's open engagements, about the step on screen (or the account as a whole), with a lead,
  a due date and details (with @mentions). It's linked back to the step, which lists its work.
- **AI audit** (with the AI plugin on, 1.2 or newer): a sheet two-thirds of the window wide that
  takes the website's domain and reads it from outside, without logging in anywhere: the domain's
  Google and Meta verifications (DNS and the page), how its addresses answer, and the tags on the
  landing page and in its public Tag Manager container: the Google tag and conversion IDs,
  Analytics, the Meta Pixel and its events, enhanced conversions, Consent Mode and the consent
  banner, phone links, forms and a gclid field. The install's AI turns that into a recommendation
  per step, listed on the sheet's left; the one picked shows on its right, to approve as it is,
  change and approve, or reject. Approving records it on the step as yours (in the history). Only
  public addresses are fetched.
- Never a password, card number or secret: record where it's kept.
- **History**: every change to an ad account, its steps and its webhooks is kept, with who made it
  (a person, or their agent and the app it came through), when, and each field's before and
  after. For all ad accounts (History on the Ads page), one ad account (History on its page) or one
  step and its webhooks (History beside the step), and as a CSV download. Deleting an ad account
  keeps its history.

## Permissions

Everyone on staff sees ad accounts and records, confirms and reopens items. Adding, changing and
deleting ad accounts takes "Add, change and delete ad accounts" (owners and managers).

## Agents

Every page has its tool: `list_ad_accounts`, `show_ad_account` (each step with how to do it, and the
next step), `create_ad_account`, `update_ad_account`, `delete_ad_account`, `add_ad_account_item`,
`update_ad_account_item` (`webhooks_attributes` for the lead webhooks step), `delete_ad_account_item`,
`confirm_ad_account_item`, `reopen_ad_account_item`, `mark_ad_account_item_not_applicable`,
`add_ad_account_item_file`, `remove_ad_account_item_file`, `add_ad_account_work`, `audit_ad_account_with_ai`,
`show_ad_account_ai_audit`, `approve_ad_account_recommendation`, `reject_ad_account_recommendation` and
`ad_account_history`. "Taking a
client's ad account live" is offered to agents as a workflow.

## Developing

Clone it beside a Runwell checkout, then from Runwell:

    bin/rails "plugins:link[../plugin-ads-checklist]"
    bin/rails db:migrate
    bin/dev

Its tests run from the Runwell checkout (Runwell's own suite doesn't load plugins; the plugin's
`test/test_helper.rb` loads it and adds its tables to the test database):

    bin/rails test ../plugin-ads-checklist/test

`bin/rails agent:coverage`, `bundle exec herb lint ../plugin-ads-checklist/app/views` and
`bin/rubocop ../plugin-ads-checklist` should all be clean.

## Releasing

Bump `lib/ads_checklist/version.rb`, commit, and push a matching `vX.Y.Z` tag: the release
workflow publishes it, and installs see it as an update in Settings › Plugins.
