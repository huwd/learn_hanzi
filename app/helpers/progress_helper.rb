module ProgressHelper
  TRAJECTORY_TILES = {
    Mastery::Trajectory::STABLE => {
      label: "Stable",
      description: "holding well",
      icon: :check,
      card: "bg-green-50 dark:bg-green-900/30",
      accent: "text-green-700 dark:text-green-400",
      icon_bg: "bg-green-600 dark:bg-green-500"
    },
    Mastery::Trajectory::RECOVERING => {
      label: "Recovering",
      description: "one lapse, not yet regraduated",
      icon: :dot,
      card: "bg-amber-50 dark:bg-amber-900/30",
      accent: "text-amber-700 dark:text-amber-400",
      icon_bg: "bg-amber-600 dark:bg-amber-500"
    },
    Mastery::Trajectory::CHRONIC => {
      label: "Chronic",
      description: "graduated, relapsed twice+",
      icon: :zigzag,
      card: "bg-orange-50 dark:bg-orange-900/30",
      accent: "text-orange-700 dark:text-orange-400",
      icon_bg: "bg-orange-600 dark:bg-orange-500"
    },
    Mastery::Trajectory::STALLED => {
      label: "Stalled",
      description: "never graduated, ease flat",
      icon: :dot,
      card: "bg-red-50 dark:bg-red-900/30",
      accent: "text-red-700 dark:text-red-400",
      icon_bg: "bg-red-600 dark:bg-red-500"
    }
  }.freeze

  ICONS = {
    check: '<path d="M3 8.5l3 3 7-7" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    dot: '<path d="M8 4v5" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/><circle cx="8" cy="11.5" r="1" fill="white"/>',
    zigzag: '<path d="M2 12l3-4 3 2.5L13 4" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
  }.freeze

  TRAJECTORY_SORT_COLUMNS = {
    "word"        => "Word",
    "meaning"     => "Meaning",
    "ease"        => "Ease",
    "graduations" => "Graduations",
    "since"       => "Since",
    "next_due"    => "Next due"
  }.freeze

  def trajectory_tile_config(key)
    TRAJECTORY_TILES.fetch(key)
  end

  def trajectory_icon(type)
    tag.svg(raw(ICONS.fetch(type)), viewBox: "0 0 16 16", class: "w-3 h-3", "aria-hidden": "true") # rubocop:disable Rails/OutputSafety
  end

  # Toggles asc/desc on a repeat click of the same column; any other column
  # always starts from asc.
  def trajectory_sort_link(column, label)
    active = @sort == column
    next_direction = active && @direction != "desc" ? "desc" : "asc"
    arrow = active ? (@direction == "desc" ? " ▼" : " ▲") : ""

    link_to "#{label}#{arrow}", trajectory_page_path(sort: column, direction: next_direction, page: 1),
      class: [ "hover:underline", ("font-semibold text-indigo-600 dark:text-indigo-400" if active) ].compact.join(" ")
  end

  def trajectory_page_path(page:, sort: @sort, direction: @direction)
    learn_progress_trajectory_path(bucket: @bucket, sort: sort, direction: direction, per_page: @result.per_page, page: page)
  end
end
