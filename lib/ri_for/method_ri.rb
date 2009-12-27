# originally gleaned from http://p.ramaze.net/17901
require 'rubygems'
require 'rdoc'
require 'rdoc/ri/driver'
require 'sane'
if RUBY_VERSION < '1.9'
  require 'ruby2ruby'
  require 'parse_tree'
  gem 'rdp-arguments' # TODO why is this necessary?
  require 'arguments' # rogerdpack-arguments
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

    string = to_s

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
    full_name = "#{class_name}#{joiner}#{method_name}"
    puts "sig: #{to_s}      arity: #{arity}"
    # TODO add to doc, I want it before ri for now though, and only once, so not there yet :)


    # now gather up any other information we now about it, in case there are no rdocs

    if !(respond_to? :source_location)
      # pull out names for 1.8
      begin
        klass = eval(class_name)
        # we don't call to_ruby to overcome ruby2ruby bug http://rubyforge.org/tracker/index.php?func=detail&aid=26891&group_id=1513&atid=5921
        if joiner == '#'
          doc << RubyToRuby.new.process(ParseTree.translate(klass, method_name))
        else
          doc << RubyToRuby.new.process(ParseTree.translate(klass.singleton_class, method_name))
        end
        args = Arguments.names(klass, method_name) rescue Arguments.names(klass.singleton_class, method_name)
        out = []
        args.each{|arg_pair|
          out << arg_pair.join(' = ')
        } if args
        out = out.join(', ')
        param_string = out
        return out if want_just_summary

        param_string = "Parameters: #{method_name}(" + out + ")" 
        doc << param_string unless want_the_description_returned
      rescue Exception => e

        puts "fail to parse tree: #{class_name} #{e} #{e.backtrace}" if $VERBOSE
      end
    else
      # 1.9.x
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
          doc.unshift "     " + $1.strip
        end
        doc.unshift " at #{file}:#{line}"

        # now the real code will end with 'end' same whitespace as the first
        sig_white_space = sig.scan(/\W+/)[0]
        body = all_lines[line..-1]
        body.each{|line|
          doc << line
          if line.start_with?(sig_white_space + "end")
            break
          end
        }
        already_got_ri = true
        param_string = sig
        return sig + "\n" + head[0] if want_just_summary
      else
        doc << 'appears to be a c method'
      end
      if respond_to? :parameters
        doc << "Original code signature: %s" % sig.to_s.strip if sig
        doc << "#parameters signature: %s( %p )" % [name, parameters]
      end
    end

    puts doc # always output it since RI does currently [todo make optional I suppose, and non out-putty]


    # now run default RI for it
    begin
      puts 'searching ri for ' + full_name + "..."
      RDoc::RI::Driver.run [full_name, '--no-pager'] unless want_just_summary
    rescue *[StandardError, SystemExit]
      # not found
    ensure
      puts '(end ri)'
    end unless already_got_ri

    if want_the_description_returned # give them something they can examine
      doc
    else
      param_string # one liner
    end
  end

  alias :desc :ri
end

class Method; include SourceLocationDesc; end
class UnboundMethod; include SourceLocationDesc; end

# TODO mixin from a separate module
class Object
  # currently rather verbose, but will attempt to describe all it knows about a method
  def ri_for name, options = {}
    if self.is_a?(Class) || self.is_a?(Module)
      # i.e. String.strip
      begin
        instance_method(name).ri(options) 
      rescue NameError => e #allows for Class.instance_method_name
        puts e, e.backtrace
        method(name).ri(options) 
      end
    else
      method(name).desc(options)
    end
  end
end


=begin 
doctest:
>> require 'pathname'
it should display the name
>> Pathname.instance_method(:children).desc(:want_the_description_returned => true).grep(/children/).size > 0
=>  true # ["#<UnboundMethod: Pathname#children>"]

and arity
>> Pathname.instance_method(:children).desc(:want_the_description_returned => true).grep(/arity/)
=> ["#<UnboundMethod: Pathname#children>     arity: -1"]

# todo: one that is guaranteed to exit you early [no docs at all ever]

wurx with class methods
>> class A; def self.go(a = 3); a=5; end; end
>> class A; def go2(a=4) a =7; end; end
>> A.ri_for(:go)
>> A.ri_for(:go2)

>> File.ri_for :delete

=end