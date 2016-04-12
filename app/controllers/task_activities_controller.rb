class TaskActivitiesController < ApplicationController

  load_and_authorize_resource

  def take
    # authorize manually, couldn't make work with load_and_authorize_resource
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?

    @task_activities = "Taking a task..."

    in_progress_systems = current_user.in_progress_systems
    if in_progress_systems.size <= 0
      redirect_to task_activities_system_description_url
    else
      @files = FileExample.all_by_user_group(current_user).where(system_example: in_progress_systems.first)
      @task_progress = current_user.task_progresses.where(done: false).first
    end
  end

  def finish
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?
    task_progress = TaskProgress.find(params[:task_progress])
    task_progress.update_attribute(:done, true)
    redirect_to task_activities_system_description_url
  end

  def system_description
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?

    @experiment_finished = false
    @system_randomly_selected = SystemExample.new
    @task_randomly_selected = Task.new

    in_progress_tasks = current_user.in_progress_tasks

    if in_progress_tasks.size > 0
      @system_randomly_selected = in_progress_tasks.first.system_example
      @task_randomly_selected = in_progress_tasks.first
    else
      unfinished_system_examples = current_user.in_progress_systems.size > 0 ? current_user.in_progress_systems : current_user.unfinished_systems

      if unfinished_system_examples.size > 0
        @system_randomly_selected = unfinished_system_examples.sample
        @task_randomly_selected = current_user.unfinished_tasks(@system_randomly_selected).sample
        # Create a task progress
        TaskProgress.create(user: current_user, task: @task_randomly_selected, done: false)
      else
        # user has finished all tasks
        @experiment_finished = true
      end
    end
  end
end
