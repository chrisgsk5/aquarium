require 'net/http'
require 'json'

class TakeInstruction < Instruction

  attr_reader :object_type, :quantity, :var, :object, :object_name

  def initialize object_type, quantity, var
    @object_type = object_type
    @quantity = quantity
    @num_taken = 0
    @var = var
    @renderable = true
    @url = 'http://bioturk.ee.washington.edu:3010/liaison/'

    super 'take'
  end

  def render scope

    # ask btor for object info
    @object_type = scope.substitute @object_type
    @obj = liaison 'info', { name: @object_type }

    if @obj[:error]
      raise @obj[:error]
    end

    # show all the locations and quantities
    puts "Locations for object type #{@object_type}"
    puts "-------------------------------------------"
    puts "   \tLocation\tQuantity Available"
    n = 0
    @obj[:inventory].each do |item| 
      available = item[:quantity]-item[:inuse]
      if available > 0 
        n += 1
        puts "  #{n}.\t#{item[:location]}\t\t#{available} "
      end
    end
    puts "-------------------------------------------"

    puts "Scope in render of take is: "
    puts scope
    
    puts "In render:: quantity = "
    @quantity = scope.evaluate( scope.substitute( @quantity.to_s ) )
    puts @quantity

    # prompt the user for which location(s) they want to use
    if ( n > 0 )
      puts "You need #{@quantity - @num_taken} more"
      print "Choose the location from which you will take one more item and press return: "
    else
      raise "not enough items of type #{@object_type} available"
    end

  end

  def execute scope

    scope.set @var.to_sym, []

    begin

      # wait for input
      location = gets.to_i - 1

      # take the object
      @item = liaison 'take', { id: @obj[:inventory][location][:id], quantity: 1 }

      if @item[:error]
        raise @item[:error]
      end    

      # add a PdlItem to scope
      v = scope.get( @var.to_sym )
      scope.set( @var.to_sym, v.push( PdlItem.new( @obj, @item ) ) )

    #@quantity = scope.evaluate( scope.substitute( @quantity ) )
    puts "In execute:: quantity = "
    puts @quantity

      # update number taken
      @num_taken += 1
      if @num_taken < @quantity
        render scope
      end

    end while @num_taken < @quantity

    # if only one object, return it instead of an array containing it
    if @quantity == 1 
      scope.set( @var.to_sym, scope.get(@var.to_sym).first )
    end

  end  

  def pre_render scope, params
    @object_name = scope.substitute @object_type
    @object = ObjectType.find_by_name(@object_name)
    if !@object
      raise "In <take>: Could not find object of type '#{@object_type}'"
    end
  end

  def bt_execute scope, params

    scope.set @var.to_sym, []
    i = 0

    while params.has_key?("i#{i}")

      if params["q#{i}"]

        @item = Item.find(params["i#{i}"])
        @obj = ObjectType.find_by_name(scope.substitute @object_type)
        v = scope.get ( @var.to_sym )
        scope.set( @var.to_sym, v.push( { 
          object: @obj.attributes.symbolize_keys, 
          item: @item.attributes.symbolize_keys,
          quantity: params["q#{i}"].to_i } ) )
        @item.inuse += params["q#{i}"].to_i
        @item.save
        i += 1

      end

    end

    if @quantity == 1
      scope.set( @var.to_sym, scope.get(@var.to_sym).first )
    end

  end

end
