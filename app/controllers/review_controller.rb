class ReviewController < ApplicationController
  before_action :require_active_session, only: [ :show, :submit ]
  before_action :require_started_session, only: [ :summary ]

  def start
    tag   = Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
    queue = LearningSession::Composer.call(user: Current.user, tag: tag)

    if queue.empty?
      render :start
    else
      session[:review_queue]      = queue.map(&:id)
      session[:review_index]      = 0
      session[:review_started_at] = Time.current.iso8601
      redirect_to review_card_path
    end
  end

  def show
    @user_learning = current_card
    @position      = session[:review_index] + 1
    @total         = session[:review_queue].size
  end

  def submit
    ease = params[:ease].to_i
    return head :unprocessable_content unless (1..4).include?(ease)

    user_learning = current_card
    result = SpacedRepetition::SM2.call(user_learning: user_learning, ease: ease)

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
    end

    session[:review_index] += 1

    if session[:review_index] >= session[:review_queue].size
      redirect_to review_summary_path
    else
      redirect_to review_card_path
    end
  end

  def summary
    started_at = Time.parse(session[:review_started_at])

    @review_logs = ReviewLog.joins(:user_learning)
                            .where(user_learnings: { user: Current.user })
                            .where(created_at: started_at..)
                            .order(:created_at)
    @total = @review_logs.count
  end

  private

  def require_active_session
    redirect_to review_path unless session[:review_queue].present?
  end

  def require_started_session
    redirect_to review_path unless session[:review_started_at].present?
  end

  def current_card
    id = session[:review_queue][session[:review_index]]
    Current.user.user_learnings
           .includes(dictionary_entry: [ :meanings, { tags: :parent } ])
           .find(id)
  end
end
