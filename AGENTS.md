# Ads, a Runwell plugin — guide for AI agents

This repository is a plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install). It is
not an app on its own: run it from a Runwell checkout with `bin/rails "plugins:link[path]"`.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Use nothing else of
  the core's. Raise `requires:` in the manifest to the newest version you use.
- `AGENTS.md`: the core's conventions, which plugin code follows too.

## Rules

- Own your tables, prefixed with the key (`ads_checklist_*`), pointing at core records by id.
  Never add columns to core tables or write core rows except through core model verbs.
- Register everything in `config.to_prepare`, keyed by the plugin's key. Controllers inherit
  `AdsChecklist::ApplicationController` (404 while switched off).
- Every controller action declares an authorization rule (`allow_staff`, `require_permission`)
  and an `agent_tool` or `agent_exempt`. Reads get a `.json.jbuilder` view with `agent_ref` and a
  `summary`. Write notices an AI can act on.
- Views follow the core's ReActionView rules: strict locals on every partial's first line,
  `<%# herb:key %>` before each loop row, no inline CSS, no partials inside `form_with`. Use the
  core's helpers and shared partials (listed in the contract) and `term()` for the core's nouns.
- CSS uses Runwell's design tokens (`docs/theming.md`), in `@layer components`.
- Migrations are safe on a live install: add in one release, remove only in a later one.
- Use only gems Runwell bundles: plugins load outside Bundler.
- The core's request and job N+1 detection (Prosopite) runs in tests: no query per item in a loop.

## Layout

- `lib/ads_checklist/engine.rb`: routes, the client hook, registrations
- `app/`: models, controllers, views, stylesheet under `ads_checklist/`
- `db/migrate/`: the plugin's tables
- `test/`: Minitest, run from a Runwell checkout (`bin/rails test path/to/this/test`)

## This plugin

- It mirrors the Websites plugin (`plugin-website-checklist`): the same screens, verbs, history,
  work and AI audit. A fix to one usually belongs in the other.
- `AdsChecklist::Account` (a client's ad account on one `platform`, `google` or `meta`, with its
  `external_id`: customer ID or ad account ID, and `url`: the website the ads send people to) has
  `Item`s: the steps to take it live. `Account::Defaults` holds one standard checklist per
  platform (`GOOGLE`, `META`), in order (access and billing, then tracking, campaigns, launch,
  after launch), with each step's `how` and `example`, read from code rather than stored.
  `Account#apply_standard_checklist` adds its platform's missing steps and brings order and
  wording up to date (on create, and in a migration when a list changes). Item keys start with the
  platform and are fixed once used (`google:tracking:conversions`, `custom:<hex>`). The platform
  can't change after creation: it decides the steps.
- `Item` holds the verbs: `confirm`, `mark_not_applicable`, `reopen`, `revise` (a person's
  change; a new value is to confirm again) and `record` (save and confirm). State is one of
  `unconfirmed`, `confirmed`, `not_applicable`; `confirmed_value` is what was confirmed.
- The lead webhooks step (`Item#webhooks?`: `google:webhooks`, `meta:webhooks`) records `Webhook`s (name, url, `pairs` of keys and values)
  through nested attributes; its value is them written out. The form is a repeater over the
  plugin's own `ads-checklist--repeater` Stimulus controller
  (`app/javascript/ads_checklist/controllers/repeater_controller.js`), built in `AccountsHelper`
  (partials can't render in a form).
- Every change is audited (`Audited`, included in `Account`, `Item` and `Webhook`): an `Audit` per
  create, update and delete with the changed fields' before and after as people read them, who
  (`Current.user`, `Current.source`, the token's name) and the account, written in the save's
  transaction. Bulk writes that skip callbacks (`insert!`, `delete_all`) aren't audited: keep
  them to system work (`apply_standard_checklist`, an account's deletion, which is audited
  itself). A
  verb should save once so a change is one entry (`Item#record`). `AuditsController` shows them.
- Steps keep files (`Item#files`, Active Storage; `add_file` / `remove_file` audit them).
- The AI audit: `Scan` (the website's domain) runs in `ScanJob`: `Account::Probe` gathers facts
  from outside (the domain's verifications through Resolv; the landing page, the account's `url`
  when it's on that domain, and the public Tag Manager container over Net::HTTP with timeouts,
  size caps and a refusal of private addresses; every part fails on its own): Google Ads,
  Analytics and Tag Manager IDs, conversion IDs, the Meta Pixel and its events, consent tools,
  phone links, forms. Then the AI plugin's `Ai.structured` (1.2.0; checked with
  `Scan.ai_available_for?`, so this plugin works without it) answers a strict schema of
  recommendations, one per step key. `Recommendation#approve!` records through `Item#record` as
  the approver; `reject!` leaves the step alone. The sheet is `scans/index` in a lazy frame inside
  a modal on the account's page; its Done link reloads the page.
- Work from an account's page (`TodosController`): a core `Todo` made on one of the client's open
  engagements through the model (`todo.created` recorded as the core does), linked by `TodoLink`
  (account, optional step, todo id) and listed on the step; a todo deleted in the core drops out.
