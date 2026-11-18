# The six assignments in Apply Yourself to the Field Ministry (docs/design/meeting-parts.md, The assignments). The
# congregation decides who gives which, so every kind is offered to everyone.
class MeetingPart::Kind
  attr_reader :key, :label, :detail, :other_speaker

  def initialize(key, label:, form:, detail: nil, other_speaker: nil)
    @key, @label, @form, @detail, @other_speaker = key, label, form, detail, other_speaker
  end

  ALL = [
    new("starting_a_conversation", label: "Starting a Conversation", form: :demonstration, other_speaker: "Householder"),
    new("following_up", label: "Following Up", form: :demonstration, other_speaker: "Householder"),
    new("making_disciples", label: "Making Disciples", form: :demonstration, other_speaker: "Bible student"),
    new("explaining_beliefs_demonstration", label: "Explaining Your Beliefs", detail: "Demonstration", form: :demonstration, other_speaker: "Other person"),
    new("explaining_beliefs_talk", label: "Explaining Your Beliefs", detail: "Talk", form: :talk),
    new("talk", label: "Talk", form: :talk)
  ].freeze

  def self.all = ALL
  def self.keys = ALL.map(&:key)
  def self.find(key) = ALL.find { it.key == key }

  def demonstration? = @form == :demonstration
  def talk? = @form == :talk

  # In the dialog's select, where Explaining Your Beliefs is listed twice.
  def option_label
    detail ? "#{label} (#{detail.downcase})" : label
  end
end
