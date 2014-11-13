
if RUBY_VERSION < '1.9'
  unless RUBY_PLATFORM =~ /java/
    require 'ruby2ruby'
    require 'parse_tree'
    gem 'rdp-arguments' # TODO why is this necessary?
    require 'arguments' # rdp-arguments
  end
end

class Object
  def singleton_class
    class << self; self; end
  end
end

module SourceLocationDesc

  # add a Method#desc which spits out all it knows about that method
  # ri, location, local ri, etc.
  # TODO does this work with class methods?
  def ri options = {}
    want_just_summary = options[:want_just_summary]
    want_the_description_returned = options[:want_the_description_returned]
    doc = []
    # to_s is something like "#<Method: String#strip>"
    # or #<Method: GiftCertsControllerTest(Test::Unit::TestCase)#get>
    # or "#<Method: A.go>"
    # or "#<Method: Order(id: integer, order_number: integer).get_cc_processor>"
    # or "#<Method: Order(id: integer, order_number: integer)(ActiveRecord::Base).get_cc_processor>"

    string = param_string = to_s

    # derive class_name
    parenthese_count = string.count '('

    if parenthese_count== 1
      # case #<Method: GiftCertsControllerTest(Test::Unit::TestCase)#get>
      # case #<Method: Order(id: integer, order_number: integer).get_cc_processor>
      if string.include? "id: " # TODO huh?
        string =~ /Method: (.+)\(/
      else
        string =~ /\(([^\(]+)\)[\.#]/ # extract out what is between last parentheses
      end
      class_name = $1
    elsif parenthese_count == 0
      # case "#<Method: A.go>"
      string =~ /Method: ([^#\.]+)/
      class_name = $1
    elsif parenthese_count == 2
      # case "#<Method: Order(id: integer, order_number: integer)(ActiveRecord::Base).get_cc_processor>"
      string =~ /\(([^\(]+)\)[\.#]/
      class_name = $1
    else
      raise 'bad ' + string
    end

    # now get method name, type
    string =~ /Method: .*([#\.])(.*)>/ # include the # or .
    joiner = $1
    method_name = $2
    full_name = class_name + joiner + method_name
    sig = "sig: #{full_name} arity #{arity}"
    # doc << sig
    param_string = sig

    # now gather up any other information we now about it, in case there are no rdocs, so we can see it early...

    if !(respond_to? :source_location)

    else
      # 1.9.x or REE
      file, line = source_location
      param_string = to_s
      if file
        # then it's a pure ruby method
        all_lines = File.readlines(file)
        head_and_sig = all_lines[0...line]
        sig = head_and_sig[-1]
        head = head_and_sig[0..-2]

        doc << sig
        head.reverse_each do |line|
          break unless line =~ /^\s*#(.*)/
          # doc.unshift "     " + $1.strip
        end
        # doc.unshift " at #{file}:#{line}"

        # now the real code will end with 'end' same whitespace as the first
        sig_white_space = sig.scan(/^\W+/)[0] || ""
        body = all_lines[line..-1]
        body.each{|line|
          doc << line
          if line.start_with?(sig_white_space + "end")
            break
          end
        }
        already_got_ri = true
        param_string = sig
        # return sig + "\n" + head[0] if want_just_summary
      else
        # doc << 'appears to be a c method'
      end
    end
    doc.join.length

  end

  alias :desc :ri

end

# TODO mixin from a separate module

class Object
  # currently rather verbose, but will attempt to describe all it knows about a method
  def count_for name, options = {}
    if self.is_a?(Class) || self.is_a?(Module)
      # i.e. String.strip
      begin
        instance_method(name).ri(options)
      rescue NameError => e #allow for Class.instance_method_name, Module.instance_method_name
        begin
          method(name).ri(options)
        rescue NameError
          raise NameError.new("appears that this object #{self} does not have this method #{name}")
        end
      end
    else
      method(name).desc(options)
    end
  end
end

class Method;
  include SourceLocationDesc
  alias ri_for ri # allow for File.method(:delete).ri_for as well
end

class UnboundMethod
  include SourceLocationDesc
  alias ri_for ri
end
