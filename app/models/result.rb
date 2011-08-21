class Result < ActiveRecord::Base
  belongs_to :player
  belongs_to :opponent, :class_name => 'Player'

  before_validation :normalise_attributes

  validates_numericality_of :round, :only_integer => true, :greater_than => 0
  validates_inclusion_of    :result, :in => %w(W L D), :message => "should be W, L or D (and not %{value})"
  validates_inclusion_of    :rateable, :in => [true, false], :message => "should be true or false (and not %{value})"
  validates_inclusion_of    :colour, :in => %w(W B), :allow_nil => true, :message => "should be W or B (and not %{value})"

  def score()           case result when 'W'; 1.0 when 'L'; 0.0 else 0.5 end end
  def opposite_result() case result when 'W'; 'L' when 'L'; 'W' else 'D' end end
  def opposite_colour() case colour when 'W'; 'B' when 'B'; 'W' else nil end end

  # The opponent's result (if there is one) or the opposite result.
  def opponents_result
    result = opponent.result_in_round(round) if opponent
    result ? result.result : opposite_result
  end

  # Build a Result from the corresponding object in the icu_tournament object.
  def self.build_from_icut(icur, player)
    attrs = {}
    attrs[:round]       = icur.round
    attrs[:result]      = icur.score
    attrs[:opponent_id] = icur.opponent unless icur.opponent.blank?
    attrs[:colour]      = icur.colour   unless icur.colour.blank?
    attrs[:rateable]    = icur.rateable
    player.results.build(attrs)
  end

  # Update both the current result and that of the opponent (if there is one).
  def update_results(attrs, opponents_result)
    attrs[:opponent_id] = attrs[:opponent_id].to_i
    attrs[:opponent_id] = nil unless attrs[:opponent_id] > 0
    attrs[:colour]      = nil if attrs[:colour].blank?
    attrs[:rateable]    = attrs[:opponent_id] ? attrs[:rateable] == "true" : false

    old_opponent = opponent
    return false unless update_attributes(attrs)
    new_opponent = opponent(true)

    begin
      if new_opponent
        new_attrs = {}
        new_attrs[:result]      = rateable ? opposite_result : opponents_result
        new_attrs[:colour]      = opposite_colour
        new_attrs[:rateable]    = rateable
        new_attrs[:opponent_id] = player.id
        new_result = new_opponent.result_in_round(round)
        if new_result
          new_result.update_attributes!(new_attrs)
        else
          new_attrs[:round] = round
          new_opponent.results.create!(new_attrs)
        end
      end

      if old_opponent && old_opponent != new_opponent
        old_attrs = {}
        old_attrs[:rateable]    = false
        old_attrs[:opponent_id] = nil
        old_result = old_opponent.result_in_round(round)
        old_result.update_attributes!(old_attrs)
      end
    rescue => ex
      logger.error "#{ex.class}: #{ex.message}"
      return false
    end

    true
  end
  
  private

  def normalise_attributes
    self.colour = nil if colour.to_s.match(/^\s*$/)
  end
end