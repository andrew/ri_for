# originally gleaned from http://p.ramaze.net/17901
require 'rubygems'
require 'rdoc'
require 'rdoc/ri/driver'
require 'sane'
begin
  gem 'arguments' # TODO why is this necessary?
  require 'arguments' # rogerdpack-arguments
rescue LoadError
  require 'arguments' # 1.9
end
require 'ruby2ruby'

module SourceLocationDesc

  # add a Method#desc which spits out all it knows about that method
  # ri, location, local ri, etc.
  # TODO does this work with class methods?
  def desc want_just_summary = false
    doc = []

    # to_s is something like "#<Method: String#strip>"
    # or #<Method: GiftCertsControllerTest(Test::Unit::TestCase)#get>
    # or "#<Method: A.go>"
    string = to_s
    joiner = '#'

    if string.include? '('
      # case #<Method: GiftCertsControllerTest(Test::Unit::TestCase)#get>
      string =~ /\((.*)\)/ # extract out what is between parentheses for the classname
      class_name = $1
    elsif string =~ /Method: (.*)\..*>/
      # case "#<Method: A.go>"
      class_name = $1
      joiner = '.'
    else
      # case "#<Method: String#strip>"
      string =~ /Method: (.*)#.*/
      class_name = $1
    end

    string =~ /Method: .*[#\.](.*)>/
    method_name = $1
    full_name = "#{class_name}#{joiner}#{method_name}"

    # now run default RI for it
    begin
      puts 'ri for ' + full_name
      RDoc::RI::Driver.run [full_name, '--no-pager'] unless want_just_summary
    rescue *[StandardError, SystemExit]
      # not found
    end

    # now gather up any other information we now about it, in case there are no rdocs

    if !(respond_to? :source_location)
      # pull out names for 1.8
      begin
        klass = eval(class_name)
        args = Arguments.names( klass, method_name) rescue Arguments.names(klass.singleton_class, method_name)
	out = []
	args.each{|arg_pair|
	  out << arg_pair.join(' = ')
	}
	out = out.join(',')
	return out if want_just_summary
	
        doc << "#{full_name} " + out
	doc << to_ruby rescue nil # TODO doesn't work for class methods currently...yeah.
      rescue Exception => e
        puts "fail to parse tree: #{class_name} #{e} #{e.backtrace}" if $VERBOSE
      end
    else
      # 1.9.x
      file, line = source_location
      doc << source_location
      if file
        # then it's a pure ruby method
	all_lines = File.readlines(file)
        head_and_sig = all_lines[0...line]
        sig = head_and_sig[-1]
        head = head_and_sig[0..-2]

        # needs more sophistication, but well... :)
        head.reverse_each do |line|
          break unless line =~ /^\s*#(.*)/
          doc.unshift "     " + $1.strip
        end
	doc << sig

        # now the real code will end with 'end' same whitespace as the first
	sig_white_space = sig.scan(/\W+/)[0]
	body = all_lines[line..-1]
	all_lines.each{|line|
	  doc << line
	  if line.start_with?(sig_white_space + "end")
	   break
	  end
	}
	# how do I get the rest now?
	
        return sig + "\n" + head[0] if want_just_summary
      else
        doc << 'appears to be a c method'
      end
      doc << full_name
    end

    if respond_to? :parameters
      prog_sig = "Signature from #parameters: %s %p" % [name, parameters]
      orig_sig = "Original code signature: %s" % sig.to_s.strip
      doc = [prog_sig, orig_sig, ''] + doc
    end
    # put arity at the end
    doc += [to_s, "arity: #{arity}"]
    puts doc # always output it since RI does currently [todo]

    doc # give them something they can examine
  end

  named_args_for :desc # just for fun, tests use it too, plus it should actually wurk without interfering...I think

end

class Method; include SourceLocationDesc; end
class UnboundMethod; include SourceLocationDesc; end

# TODO mixin a separate module
class Object
  # currently rather verbose, but will attempt to describe all it knows about a method
  def method_desc name, options = {}
    if self.is_a? Class
      # i.e. String.strip
      instance_method(name).desc(options) # rescue method(name).desc # allow for Class.instance_method_name I suppose
    else
      method(name).desc(options)
    end
  end
  alias :desc_method :method_desc # you can have it either way
end




=begin 
doctest:
>> require 'pathname'
it should display the name
>> Pathname.instance_method(:children).desc(:want_output => true).grep(/children/).size > 0
=>  true # ["#<UnboundMethod: Pathname#children>"]

and arity
>> Pathname.instance_method(:children).desc(:want_output => true).grep(/arity/)
=>  ["arity: -1"]

# todo: one that is guaranteed to exit you early [no docs at all ever]

wurx with class methods
>> class A; def self.go(a = 3); a=5; end; end
>> class A; def go2(a=4) a =7; end; end
>> A.desc_method(:go)
>> A.desc_method(:go2)

>> File.desc_method :delete

=end