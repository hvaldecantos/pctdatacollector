class TaskActivitiesController < ApplicationController

  load_and_authorize_resource

  def take
    # authorize manually, couldn't make it work with load_and_authorize_resource
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?

    @task_activities = "Taking a task..."

    in_progress_systems = current_user.in_progress_systems
    if in_progress_systems.size <= 0 # incase someone goes directly to take_path the task without going first to system_description_path
      redirect_to task_activities_system_description_url
    else # a system and a task have been assigned
      @files = FileExample.all_by_user_group(current_user).where(system_example: in_progress_systems.first)

      ##########################################
      # Set the order from the field task_file_ids_order of the current user using stored_task_file_ids_order method
      @files = @files.shuffle
      file_ids = @files.collect{|f| f.id }

      if current_user.stored_file_ids_has_exactly_the_same_elements_of? file_ids
        # Use the stored file ids order
        current_user.stored_task_file_ids_order.each_with_index do |stored_file_id, index|
          @files.insert(index, @files.delete_at(@files.index(FileExample.find(stored_file_id))))
        end
      else
        # Use the shuffled files
        current_user.update_attribute(:task_file_ids_order, file_ids.to_s)
      end
      ##########################################

      @task_progress = current_user.task_progresses.where(done: false)
                                   .select{|pt| pt.system_example.is_for_training == current_user.is_in_training }.first
    end
  end

  def finish
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?
    task_progress = TaskProgress.find(params[:task_progress_id])
    task_progress.update_attributes(done: true, answer: "{\"answer\" : #{params['answer']}}")
    render js: "window.location = '#{task_activities_system_description_url}'"
  end

  def system_description
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?
    @experiment_finished = false
    # @system_randomly_selected = SystemExample.new
    # @task_randomly_selected = Task.new

    in_progress_tasks = current_user.in_progress_tasks.select{|pt| pt.system_example.is_for_training == current_user.is_in_training &&
                                                                   pt.system_example.disabled == false }


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
        current_user.update_attribute(:training_done, true)
      end
    end

    if @experiment_finished == false
      @number_of_systems = current_user.all_systems.size
      @number_of_finished_systems = current_user.finished_systems.size + 1
      @number_of_tasks = Task.where(system_example: @task_randomly_selected.system_example).size
      @number_of_finished_tasks = current_user.finished_tasks.where(system_example: @task_randomly_selected.system_example).size + 1
    end

    if current_user.group == ".java"
      @paradigm = "Object-Oriented"
      @language = "java"
    elsif current_user.group == ".k"
      @paradigm = "Data Context Interaction"
      @language = "trygve"
    else
      @paradigm = "n/a"
      @language = "n/a"
    end
  end

  def retake
    raise CanCan::AccessDenied.new("You are not authorized to access this page.", :take, TaskActivity) if current_user.nil?
    if current_user.is_in_training
      current_user.task_progresses.joins(:system_example).where('system_examples.is_for_training = TRUE').destroy_all

      respond_to do |format|
        format.html { redirect_to :back, notice: 'You have decided to retake the training experiment.' }
        format.json { head :no_content }
      end
      return
    end
  end
end
