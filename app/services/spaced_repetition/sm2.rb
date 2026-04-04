module SpacedRepetition
  class SM2
    DEFAULT_FACTOR = 2500
    MIN_FACTOR = 1300
    EASY_BONUS = 1.3

    Result = Data.define(:interval, :factor, :next_due, :new_state)

    def self.call(user_learning:, ease:)
      new(user_learning, ease).call
    end

    def initialize(user_learning, ease)
      @user_learning = user_learning
      @ease = ease
    end

    def call
      Result.new(
        interval: calculated_interval,
        factor: calculated_factor,
        next_due: calculated_interval.days.from_now,
        new_state: calculated_state
      )
    end

    private

    def current_interval
      [ @user_learning.last_interval.to_i, 1 ].max
    end

    def current_factor
      f = @user_learning.factor.to_i
      f.zero? ? DEFAULT_FACTOR : f
    end

    def calculated_interval
      case @ease
      when 1 then 1
      when 2 then [ (current_interval * 1.2).ceil, 1 ].max
      when 3 then [ (current_interval * current_factor / 1000.0).ceil, 1 ].max
      when 4 then [ (current_interval * current_factor / 1000.0 * EASY_BONUS).ceil, 1 ].max
      end
    end

    def calculated_factor
      case @ease
      when 1 then [ current_factor - 200, MIN_FACTOR ].max
      when 2 then [ current_factor - 150, MIN_FACTOR ].max
      when 3 then current_factor
      when 4 then current_factor + 150
      end
    end

    def calculated_state
      case [ @user_learning.state, @ease ]
      in [ "new", (1 | 2 | 3 | 4) ] then "learning"
      in [ "learning", (1 | 2) ]     then "learning"
      in [ "learning", (3 | 4) ]     then "mastered"
      in [ "mastered", 1 ]            then "learning"
      in [ "mastered", (2 | 3 | 4) ] then "mastered"
      else @user_learning.state
      end
    end
  end
end
