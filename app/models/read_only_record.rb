class ReadOnlyRecord < ApplicationRecord
  self.abstract_class = true

  def readonly?
    true
  end

  def before_destroy
    raise ActiveRecord::ReadOnlyRecord
  end
end
