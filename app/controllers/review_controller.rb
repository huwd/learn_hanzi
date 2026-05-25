class ReviewController < ApplicationController
  before_action :require_active_session, only: [ :show, :submit ]
  before_action :require_completed_session, only: [ :summary ]
  around_action :measure_action_performance, only: [ :show, :submit ]

  def start
    Current.user.learning_sessions.in_progress.update_all(state: "abandoned")

    tag   = Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
    queue = LearningSession::Composer.call(
      user:    Current.user,
      size:    Current.user.session_size,
      new_cap: Current.user.new_cards_per_session,
      tag:     tag
    )

    if queue.empty?
      render :start
    else
      ls = build_learning_session(queue)
      session[:learning_session_id] = ls.id
      session[:review_position]     = 0
      redirect_to review_card_path
    end
  end

  def show
    @learning_session = measure_performance("review_show_session_lookup") { active_learning_session }
    @session_card     = measure_performance("review_show_session_card_lookup") do
      @learning_session.current_card(current_position)
    end
    @user_learning    = measure_performance("review_show_user_learning_lookup") do
      UserLearning
        .includes(dictionary_entry: [
          { meanings: :source },
          { tags: :parent },
          { audio_pronunciations: { audio_attachment: :blob } },
          :stroke_order_datum,
          { dictionary_entry_radicals: :radical }
        ])
        .find(@session_card.user_learning_id)
    end
    @position         = current_position + 1
    @total            = @learning_session.card_count
    @related_anchors  = measure_performance("review_show_related_anchors") do
      RelatedAnchorBuilder.call(
        user: Current.user,
        target_learning: @user_learning,
        limit: 5
      )
    end
    @radical_breakdown = measure_performance("review_show_radical_breakdown") do
      RadicalBreakdownBuilder.call(
        user: Current.user,
        dictionary_entry: @user_learning.dictionary_entry
      )
    end
    @stroke_order_diagrams = measure_performance("review_show_stroke_order_diagrams") do
      StrokeOrderDiagramBuilder.call(dictionary_entry: @user_learning.dictionary_entry)
    end
  end

  def submit
    ease = params[:ease].to_i
    return head :unprocessable_content unless (1..4).include?(ease)

    ls           = measure_performance("review_submit_session_lookup") { active_learning_session }
    session_card = measure_performance("review_submit_session_card_lookup") do
      ls.current_card(current_position)
    end
    user_learning = session_card.user_learning
    result = measure_performance("review_submit_sm2") do
      SpacedRepetition::SM2.call(user_learning: user_learning, ease: ease)
    end

    measure_performance("review_submit_transaction") do
      ApplicationRecord.transaction do
        user_learning.update!(
          state:         result.new_state,
          last_interval: result.interval,
          factor:        result.factor,
          next_due:      result.next_due
        )

        ReviewLog.create!(
          user_learning: user_learning,
          ease:          ease,
          interval:      result.interval,
          factor:        result.factor,
          log_type:      0
        )

        session_card.update!(ease: ease, reviewed_at: Time.current)
      end
    end

    next_position = current_position + 1

    if next_position >= ls.card_count
      ls.complete!
      redirect_to review_summary_path
    else
      session[:review_position] = next_position
      redirect_to review_card_path
    end
  end

  def summary
    @learning_session = completed_learning_session
    @session_cards    = @learning_session.learning_session_cards.order(:position)
    @total            = @learning_session.reviewed_count
  end

  def history
    @sessions = Current.user.learning_sessions
                            .completed
                            .order(started_at: :desc)
  end

  private

  def build_learning_session(queue)
    ApplicationRecord.transaction do
      ls = Current.user.learning_sessions.create!(
        state:      "in_progress",
        started_at: Time.current,
        card_count: queue.size
      )
      queue.each_with_index do |user_learning, i|
        ls.learning_session_cards.create!(user_learning: user_learning, position: i)
      end
      ls
    end
  end

  def active_learning_session
    id = session[:learning_session_id]
    Current.user.learning_sessions.in_progress.find(id)
  end

  def completed_learning_session
    id = session[:learning_session_id]
    Current.user.learning_sessions.completed.find(id)
  end

  def current_position
    session[:review_position].to_i
  end

  def require_active_session
    active_learning_session
  rescue ActiveRecord::RecordNotFound
    redirect_to review_path
  end

  def require_completed_session
    completed_learning_session
  rescue ActiveRecord::RecordNotFound
    redirect_to review_path
  end
end
