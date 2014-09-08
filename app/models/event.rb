# == Schema Information
#
# Table name: events
#
#  id               :integer          not null, primary key
#  name             :string(255)
#  slug             :string(255)
#  description      :text
#  venue_id         :integer
#  start_at         :datetime
#  end_at           :datetime
#  parent_id        :integer
#  logo             :string(255)
#  devcon_role      :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  summary          :text
#  schedule         :text
#  rules            :text
#  registration     :text
#  published        :boolean          default(FALSE)
#  event_type       :string(255)
#  target_attendees :integer
#  actual_attendees :integer
#  cover_photo      :string(255)
#

class Event < ActiveRecord::Base
  include ActionView::Helpers

  belongs_to :venue
  has_many :subevents, -> { order(:start_at) }, :class_name => "Event", :foreign_key => :parent_id
  belongs_to :parent, :class_name => "Event"
  has_many :event_partners
  has_many :entities, :through => :event_partners

  include SluggedResource
  include Icalendar

  mount_uploader :logo, ThumbnailUploader
  mount_uploader :cover_photo, CoverPhotoUploader

  scope :upcoming, -> { where("start_at > current_timestamp").order("start_at") }
  scope :current, -> { where("start_at <= current_timestamp and end_at >= current_timestamp").order("start_at") }
  scope :finished, -> { where("end_at < current_timestamp").order("end_at DESC") }
  scope :include_subevents, -> { where(:parent_id => nil).includes(:subevents) }

  def venues
    ([venue] + subevents.map { |e| e.venue }).compact.uniq
  end

  def effective_address
    if venue.nil?
      unless venues.empty?
        venues[0].address
      else
        nil
      end
    else
      venue.address
    end
  end

  def self.previous_by_month
    finished.include_subevents.group_by do |event|
      event.start_at.strftime("%B %Y")
    end
  end

  def google_calendar_url
    start_time = self.start_at.utc.strftime("%Y%m%dT%H%M00Z")
    end_time = self.end_at.utc.strftime("%Y%m%dT%H%M00Z")
    values = {
      action: 'TEMPLATE',
      text: self.name,
      dates: "#{start_time}/#{end_time}",
      details: truncate(strip_tags(HTMLEntities.new.decode(self.description)), length: 200),
      location: self.effective_address,
      trp: true,
      sprop: 'website:http://devcon.ph'
    }

    'http://google.com/calendar/event?' + values.to_query
  end

  def icalendar(event_url)
    event_temp = self
    cal = Calendar.new

    cal.event do |e|
      e.dtstart = event_temp.start_at.strftime("%Y%m%dT%H%M00")
      e.dtend = event_temp.end_at.strftime("%Y%m%dT%H%M00")
      e.summary = event_temp.name
      e.description = event_temp.summary
      e.ip_class = 'PRIVATE'
      e.url = event_url

      e.alarm do |a|
        a.action = 'DISPLAY'
        a.summary = 'Event notification'
        a.trigger = '-P1DT0H0M0S'
      end
    end

    cal.to_ical
  end
end
