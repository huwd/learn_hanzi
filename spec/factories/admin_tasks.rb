FactoryBot.define do
  factory :admin_task do
    task_type { "cc_cedict" }
    state     { "pending" }
  end
end
