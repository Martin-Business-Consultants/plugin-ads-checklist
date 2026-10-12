module AdsChecklist
  # A piece of the core's work made from an ad account's page, and the step it's about (if any).
  class TodoLink < ApplicationRecord
    belongs_to :account
    belongs_to :item, optional: true
    belongs_to :todo, class_name: "::Todo"
  end
end
