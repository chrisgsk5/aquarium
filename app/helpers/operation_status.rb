

# Module that includes status-related methods for {Operation}

module OperationStatus

  # Set and save {Operation} status
  #
  # @param str [String] ("waiting", "pending", "primed", "deferred", "scheduled", "running", "done", "error")
  # @return [String] The {Operation} status
  def change_status(str)
    temp = status
    self.status = str
    save
    raise 'Could not change status' unless errors.empty?
    str
  end

  def start

    raise "Cannot start operation #{id} from state #{status}" unless status == 'planning'

    if on_the_fly
      change_status 'primed'
    elsif leaf? # note that this op is considered a leaf if it has no preds,
      # or if its preds are all on_the_fly leaves
      if precondition_value
        change_status 'pending'
      else
        change_status 'delayed'
      end
    else
      change_status 'waiting'
    end

  end

  def retry

    raise "Cannot restart operation #{id} because it is not in an error state" unless status == 'error' || status == 'done'
    change_status 'waiting'
    step

  end

  def schedule
    raise "Cannot schedule operation #{id} from state #{status}" unless status == 'pending' || status == 'deferred' || status == 'primed'
    change_status 'scheduled'
  end

  def run
    raise "Cannot run operation #{id} from state #{status}" unless status == 'scheduled'
    change_status 'running'
  end

  def defer
    raise "Cannot defer operation #{id} from state #{status}" unless status == 'pending'
    change_status 'deferred'
  end

  def unbatch; end

  def step # not to be confused with def self.step in Operation.rb

    print "op #{id}: #{status}"
    if status != 'scheduled' &&
       status != 'running' &&
       status != 'done' &&
       status != 'error' &&
       ready? # in planner/operation_planner.rb

      get_items_from_predecessor

      if on_the_fly
        change_status 'primed'
      elsif status == 'deferred'
        change_status 'scheduled'
      elsif precondition_value
        change_status 'pending'
      else
        change_status 'delayed'
      end
    end
    puts " ==> #{status}"
  rescue Exception => e
    Rails.logger.info "COULD NOT STEP OPERATION #{id}: #{e}"

    # TODO: Change deferred op to scheduled

  end

  def finish
    change_status 'done' if status == 'running'
  end

  # Set the {Operation} to "error", and create a {DataAssociation} to
  # describe why the operation errored
  #
  # @param error_type [Symbol] Name of error
  # @param msg [String] Error message
  # @example Error {Operation}s with no plate colonies
  #   op.error :no_colonies, "There are no colonies for plate #{plate}"
  # @see DataAssociator#associate
  def error(error_type, msg)
    change_status 'error'
    associate error_type, msg
  end

  # Set {Operation} status to "pending" if its precondition evaluates to true;
  # sets status to "delayed" otherwise. This is particularly useful for
  # operations that are not yet ready to be run or need to be run periodically.
  #
  # @see #change_status
  def redo
    if precondition_value
      change_status 'pending'
    else
      change_status 'delayed'
    end
    # TODO: Change preds to pending? At least on_the_fly_preds/
  end

  def get_items_from_predecessor

    inputs.each do |i|

      Wire.where(to_id: i.id).each do |wire|
        self.associate(
          :input_item_replaced, 
          "Input #{i.name} was #{i.child_item_id} but was replaced by #{wire.from.child_item_id} " +
          "(likely when its predecessor recomputed an output)",
          nil,
          duplicates: true
        ) if i.child_item_id && ( 
            i.child_item_id != wire.from.child_item_id ||
            i.row != wire.from.row ||
            i.column != wire.from.column )
        i.child_item_id = wire.from.child_item_id
        i.row = wire.from.row
        i.column = wire.from.column
        i.save
      end

    end

  end

end
