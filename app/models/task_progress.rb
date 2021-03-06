class TaskProgress < ActiveRecord::Base
  belongs_to :task
  belongs_to :user
  has_one :system_example, :through => :task

  scope :finished, -> { where(done: true) }
  scope :in_progress, -> { where(done: false) }

  # task_id and user_id should be unique?
end
