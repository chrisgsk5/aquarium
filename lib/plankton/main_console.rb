

path = '/Users/ericklavins/Development/protocols/plankton/errors/include_in_if.pl'
contents =  File.read path
p = Plankton::Parser.new( path, contents )

begin
  p.parse
rescue Exception => e
  puts e
  puts p.get_line
  exit
end

puts p.args
puts '-----------------'
p.show
