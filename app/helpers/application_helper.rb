module ApplicationHelper
  def hanzi_size_class(text)
    case text.length
    when 1, 2 then "text-9xl"
    when 3    then "text-8xl"
    else           "text-7xl"
    end
  end
end
