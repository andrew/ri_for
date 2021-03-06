The [ri_for] gem allows "runtime documentation lookup", it shows a
method's source code/comments, ri (if available), arity, parameters, 
etc. all at runtime (for example within an irb session).

Don't know what a method does? Look it up!

It has proven quite useful, and I wouldn't do a ruby-debug session
without it--you might like it.

## Examples

    >> File.ri_for :delete
    
    sig: File.delete arity -1
    appears to be a c method
    Searching ri for
    sig: File.delete arity -1
    ...
    ----------------------------------------------------------- File::delete
         File.delete(file_name, ...)  => integer
         File.unlink(file_name, ...)  => integer
    
    ------------------------------------------------------------------------
         Deletes the named files, returning the number of names passed as
         arguments. Raises an exception on any error. See also +Dir::rmdir+.
    
    (end ri)
    => "sig: File.delete arity -1"

(or alternatively use >> File.method(:delete).ri_for)

or, given this dynamically generated class, it can still show runtime parameter information:

    >> class A; 
        def go(a); end; 
       end
    
    >> A.new.ri_for :go

    sig: A#go arity 1
    def go(a)
      # do nothing
    end
    Parameters: go(a)
    Searching ri for
    sig: A#go arity 1
    ...
    Nothing known about A
    (end ri)
    => "Parameters: go(a)"

Or (my favorite) use it within debug session:

     74       assert(true == false)
     
    (rdb:1) ri_for :assert
    #<Method: StoreControllerTest(Test::Unit::Assertions)#assert>      arity: -2
    ri for Test::Unit::Assertions#assert
    ------------------------------------------ Test::Unit::Assertions#assert
         assert(boolean, message=nil)
    
         From gem test-unit-2.0.1
    ------------------------------------------------------------------------
         Asserts that +boolean+ is not false or nil.

         Example:
    
           assert [1, 2].include?(5)
    
    (end ri)
    def assert(boolean, message = nil)
      _wrap_assertion do
        assert_block("assert should not be called with a block.") do
          (not block_given?)
        end
        assert_block(build_message(message, "<?> is not true.", boolean)) { boolean }
      end
    end
    Parameters: assert(boolean, message = nil)

Thus, you can look at methods' source/rdocs without having to
run the methods and step into them.  Deftly convenient.

## Installation

    $ gem install ri_for

## Usage

    >> require 'ri_for'
    >> ClassName.ri_for :method_name # class or instance method name
    
    >> some_instance.ri_for :method_name

Other goodies included:

### Object#my_methods

Stolen from a website somewhere. An example:

    >> class A; def go; end; end
    >> A.new.my_methods
    => {:first, :second, :third]}

### Object#methods2

Like #methods, but inserts a marker after my_methods are shown:

    >> A.new.methods2
    => ["go", :"inherited methods after this point >>", "to_yaml_style", "inspect", "methods_old", "clone", "public_methods", "display", "instance_variable_defined?", "equal?", "freeze", "to_yaml_properties", "methods"...]

## Attributions

This gem wraps for convenience the functionality of Method#source_location,
ruby2ruby, et al, and was inspired by a snippet from manvenu, SourceRef (MBARI),
and Python's Method#desc.
It also wouldn't be useful without irb and the ruby-debug folks. Thanks!

## Related

[ori]: Just lists ri, not method bodies and parameters, like mine does.
       Also irb has a "help" command for obtaining (just lists ri) but
       it's pretty obscure nobody knows about it.
       
    >> help "Array"
    >> help "Array#[]" (just displays ri)

There are quite a few "#methods" helper utilties out there, too.  
irbtools also lists a lot of other irb helpers.

[method_source]: Similar, I think it's embedded in pry as well.

## Feedback

Comments/suggestions welcome rogerdpack on gmail or @rdp on github

[ori]:https://github.com/dadooda/ori
[method_source]:https://github.com/banister/method_source
[ri_for]:github.com/rdp/ri_for
