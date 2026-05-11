class LearnController < ApplicationController
  before_action :require_learn_session, only: [ :show, :submit ]
  before_action :require_review_phase,  only: [ :review_show, :review_submit ]
  before_action :require_started_session, only: [ :summary ]
  around_action :measure_action_performance, only: [ :show, :submit, :review_show, :review_submit ]

  def start
    queue_size = Current.user.new_cards_per_session

    queue = if params[:tag_id].present?
      tag = Tag.find_by(id: params[:tag_id])
      tag ? build_tagged_queue(tag, queue_size) : build_global_queue(queue_size)
    else
      build_global_queue(queue_size)
    end

    if queue.empty?
      render :start
    else
      session[:learn_queue]       = queue.map(&:id)
      session[:learn_index]       = 0
      session[:learn_started_at]  = Time.current.iso8601
      session[:learn_introduced]  = []
      redirect_to learn_card_path
    end
  end

  def show
    @user_learning = measure_performance("learn_show_user_learning_lookup") { current_card }
    @position      = session[:learn_index] + 1
    @total         = session[:learn_queue].size
    @related_anchors = measure_performance("learn_show_related_anchors") do
      RelatedAnchorBuilder.call(
        user: Current.user,
        target_learning: @user_learning,
        limit: 5
      )
    end
    @radical_breakdown = measure_performance("learn_show_radical_breakdown") do
      RadicalBreakdownBuilder.call(
        user: Current.user,
        dictionary_entry: @user_learning.dictionary_entry
      )
    end
    @stroke_order_diagrams = measure_performance("learn_show_stroke_order_diagrams") do
      StrokeOrderDiagramBuilder.call(dictionary_entry: @user_learning.dictionary_entry)
    end
  end

  def submit
    know_it = params[:know_it] == "true"
    ul      = measure_performance("learn_submit_user_learning_lookup") { current_card }

    measure_performance("learn_submit_update_user_learning") do
      if know_it
        ul.update!(state: "learning", last_interval: 1, factor: 2500, next_due: 1.day.from_now)
      else
        ul.update!(state: "learning", last_interval: 0, factor: 2500, next_due: Time.current)
      end
    end

    session[:learn_introduced] = (session[:learn_introduced] || []) + [ ul.id ]
    session[:learn_index] += 1

    if session[:learn_index] >= session[:learn_queue].size
      session[:learn_review_index] = 0
      redirect_to learn_review_path
    else
      redirect_to learn_card_path
    end
  end

  def review_show
    @user_learning = measure_performance("learn_review_show_user_learning_lookup") { current_review_card }
    @position      = session[:learn_review_index] + 1
    @total         = session[:learn_introduced].size
    @related_anchors = measure_performance("learn_review_show_related_anchors") do
      RelatedAnchorBuilder.call(
        user: Current.user,
        target_learning: @user_learning,
        limit: 5
      )
    end
    @radical_breakdown = measure_performance("learn_review_show_radical_breakdown") do
      RadicalBreakdownBuilder.call(
        user: Current.user,
        dictionary_entry: @user_learning.dictionary_entry
      )
    end
    @stroke_order_diagrams = measure_performance("learn_review_show_stroke_order_diagrams") do
      StrokeOrderDiagramBuilder.call(dictionary_entry: @user_learning.dictionary_entry)
    end
  end

  def review_submit
    ease = params[:ease].to_i
    return head :unprocessable_content unless (1..4).include?(ease)

    ul     = measure_performance("learn_review_submit_user_learning_lookup") { current_review_card }
    result = measure_performance("learn_review_submit_sm2") do
      SpacedRepetition::SM2.call(user_learning: ul, ease: ease)
    end

    measure_performance("learn_review_submit_transaction") do
      ApplicationRecord.transaction do
        ul.update!(
          state:         result.new_state,
          last_interval: result.interval,
          factor:        result.factor,
          next_due:      result.next_due
        )
        ReviewLog.create!(
          user_learning: ul,
          ease:          ease,
          interval:      result.interval,
          factor:        result.factor,
          log_type:      0
        )
      end
    end

    session[:learn_review_index] += 1

    if session[:learn_review_index] >= session[:learn_introduced].size
      redirect_to learn_summary_path
    else
      redirect_to learn_review_path
    end
  end

  def summary
    started_at   = Time.parse(session[:learn_started_at])
    @introduced  = session[:learn_introduced]&.size || 0
    @review_logs = ReviewLog.joins(:user_learning)
                            .where(user_learnings: { user: Current.user })
                            .where(created_at: started_at..)
                            .order(:created_at)
  end

  private

  # Build a queue filtered to a specific tag.
  # Priority 1: entries with no UserLearning yet ("Not Learned Yet") — create records on demand.
  # Priority 2: existing UserLearnings with state "new" for this tag.
  # Both groups are sorted by HSK level within their priority band.
  def build_tagged_queue(tag, size)
    learned_entry_ids = Current.user.user_learnings
                               .joins(:dictionary_entry)
                               .where(dictionary_entries: { id: tag.dictionary_entries.select(:id) })
                               .pluck(:dictionary_entry_id)

    unlearned_entries = tag.dictionary_entries
                           .where.not(id: learned_entry_ids)
                           .includes(tags: { parent: :parent })
                           .sort_by { |e| hsk_entry_sort_key(e) }

    existing_new = Current.user.user_learnings
                          .new_learnings
                          .joins(:dictionary_entry)
                          .where(dictionary_entries: { id: tag.dictionary_entries.select(:id) })
                          .includes(dictionary_entry: { tags: { parent: :parent } })
                          .sort_by { |ul| hsk_sort_key(ul) }

    newly_created = unlearned_entries.first(size).map do |entry|
      Current.user.user_learnings.create!(dictionary_entry: entry, state: "new")
    end

    remaining = size - newly_created.size
    (newly_created + existing_new.first(remaining))
  end

  def build_global_queue(size)
    Current.user.user_learnings
           .new_learnings
           .includes(dictionary_entry: { tags: { parent: :parent } })
           .sort_by { |ul| hsk_sort_key(ul) }
           .first(size)
  end

  def hsk_sort_key(user_learning)
    hsk_entry_sort_key(user_learning.dictionary_entry)
  end

  def hsk_entry_sort_key(entry)
    best = nil
    entry.tags.each do |tag|
      version_tag, level_tag = hsk_version_and_level(tag)
      next unless version_tag && level_tag
      level_num = level_tag.name.scan(/\d+/).first.to_i
      key = [ version_tag.name, level_num ]
      best = key if best.nil? || key < best
    end
    best || [ "\xff", Float::INFINITY ]
  end

  def hsk_version_and_level(tag)
    if tag.parent.nil?
      [ nil, nil ]
    elsif tag.parent.parent.nil?
      tag.parent.name.match?(/HSK \d+\.\d+/) ? [ tag.parent, tag ] : [ nil, nil ]
    else
      tag.parent.parent.name.match?(/HSK \d+\.\d+/) ? [ tag.parent.parent, tag.parent ] : [ nil, nil ]
    end
  end

  def require_learn_session
    redirect_to learn_path unless session[:learn_queue].present?
  end

  def require_review_phase
    redirect_to learn_path unless session[:learn_introduced].present?
  end

  def require_started_session
    redirect_to learn_path unless session[:learn_started_at].present?
  end

  def current_card
    id = session[:learn_queue][session[:learn_index]]
    Current.user.user_learnings
           .includes(dictionary_entry: [ { meanings: :source }, :audio_pronunciations ])
           .find(id)
  end

  def current_review_card
    id = session[:learn_introduced][session[:learn_review_index]]
    Current.user.user_learnings
           .includes(dictionary_entry: [ { meanings: :source }, :audio_pronunciations ])
           .find(id)
  end
end
