class Task < ActiveRecord::Base

  attr_accessible :name, :specification, :status, :task_prototype_id, :user_id
  belongs_to :task_prototype
  has_many :touches
  belongs_to :user

  validates :name, :presence => true
  validates :status, :presence => true
  validates_uniqueness_of :name, scope: :task_prototype_id

  validate :matches_prototype

  validate :legal_status

  def legal_status
    if ! JSON.parse(self.task_prototype.status_options).include? self.status
      errors.add(:status_choice, "Status must be one of " + self.task_prototype.status_options);
      return
    end
  end

  def matches_prototype

    begin
      spec = JSON.parse self.specification, symbolize_names: true
    rescue Exception => e
      errors.add(:task_json, "Error parsing JSON in prototype. #{e.to_s}")
      return
    end

    proto = JSON.parse TaskPrototype.find(self.task_prototype_id).prototype, symbolize_names: true

    type_check proto, spec

  end

  def type_check p, s

    case p

      when String

        result = (s.class == String)
        errors.add(:task_constant, ": Wrong atomic type encountered") unless result 

      when Fixnum, Float

        result = (s.class == Fixnum || s.class == Float)
        errors.add(:task_constant, ": Wrong atomic type encountered") unless result 

      when Hash

        result = (s.class == Hash)
        errors.add(:task_hash, ": Type mismatch") unless result 

        # check all requred key/values are present
        if result
          p.keys.each do |k|
            result = result && s.has_key?(k) && type_check( p[k], s[k] )
            errors.add(:task_missing_key_value, ": Specification #{s} is missing the key '#{k}' (a #{k.class})") unless result && s.has_key?(k) 
            errors.add(:task_missing_key_value, ": Specification #{s[k]} has the wrong type. Should match #{p[k]}") unless result && type_check( p[k], s[k] ) 
          end
        end

        # check that no other keys are present
        if result
            s.keys.each do |k|
            result = result && p.has_key?(k)
            errors.add(:task_extra_key, ": Specification has the key #{k} but prototype does not") unless result 
          end
        end

        when Array

          result = (s.class == Array && s.length >= p.length )
          errors.add(:task_array, ": #{s} is not an array, or is not an array of length at last #{p.length}") unless result 

          # check that elements in spec match those in prototype 
          (0..p.length-1).each do |i|
            result = result && type_check( p[i], s[i] )
            errors.add(:task_array, ": Specification has mismatch at element #{i} of #{s}") unless result 
          end          

          # check that extra elements in spec match last in prototype
          if result && p.length > 0 && s.length > p.length
            ( p.length-1 .. s.length-1 ).each do |i|
              result = result && type_check( p.last, s[i] )
              errors.add(:task_array, ": Specification has mismatch at element #{i} of #{s}. Its type should match the type of the last element of p") unless result 
            end
          end

        else
          errors.add(:task_type_check, ": Unknown type in task prototype: #{p.class}")
          result = false

      end

    result

  end

  def spec

    unless defined?(@parsed_spec)

      begin
        @parsed_spec = JSON.parse self.specification, symbolize_names: true
      rescue Exception => e
        @parsed_spec = { warnings: [ "Failed to parse task specification", e ]}
      end

    end

    @parsed_spec

  end

  def simple_spec

    Job.new.remove_types spec

  end

end
