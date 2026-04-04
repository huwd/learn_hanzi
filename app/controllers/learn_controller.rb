class LearnController < ApplicationController
  QUEUE_SIZE = 5

  before_action :require_learn_session, only: [ :show, :submit ]
  before_action :require_review_phase,  only: [ :review_show, :review_submit ]
  before_action :require_started_session, only: [ :summary ]

  def start
    queue = Current.user.user_learnings
                   .new_learnings
                   .order(:created_at)
                   .limit(QUEUE_SIZE)
                   .to_a

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
    @user_learning = current_card
    @position      = session[:learn_index] + 1
    @total         = session[:learn_queue].size

    char      = @user_learning.dictionary_entry.text
    safe_char = ActiveRecord::Base.sanitize_sql_like(char)
    @related  = Current.user.user_learnings
                       .mastered
                       .joins(:dictionary_entry)
                       .where("dictionary_entries.text LIKE ?", "%#{safe_char}%")
                       .where.not(id: @user_learning.id)
                       .includes(dictionary_entry: :meanings)
                       .limit(5)
  end

  def submit
    know_it = params[:know_it] == "true"
    ul      = current_card

    if know_it
      ul.update!(state: "learning", last_interval: 1, factor: 2500, next_due: 1.day.from_now)
    else
      ul.update!(state: "learning", last_interval: 0, factor: 2500, next_due: Time.current)
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
    @user_learning = current_review_card
    @position      = session[:learn_review_index] + 1
    @total         = session[:learn_introduced].size
  end

  def review_submit
    ease = params[:ease].to_i
    return head :unprocessable_content unless (1..4).include?(ease)

    ul     = current_review_card
    result = SpacedRepetition::SM2.call(user_learning: ul, ease: ease)

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

    session[:learn_review_index] += 1

    if session[:learn_review_index] >= session[:learn_introduced].size
      redirect_to learn_summary_path
    else
      redirect_to learn_review_path
    end
  end

  def summary
    started_at    = Time.parse(session[:learn_started_at])
    @introduced   = session[:learn_introduced]&.size || 0
    @review_logs  = ReviewLog.joins(:user_learning)
                             .where(user_learnings: { user: Current.user })
                             .where(created_at: started_at..)
                             .order(:created_at)
  end

  private

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
           .includes(dictionary_entry: [ :meanings, { tags: :parent } ])
           .find(id)
  end

  def current_review_card
    id = session[:learn_introduced][session[:learn_review_index]]
    Current.user.user_learnings
           .includes(dictionary_entry: [ :meanings, { tags: :parent } ])
           .find(id)
  end
end
