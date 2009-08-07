# this should never be shown
class A
 def self.inspect 
    "A(id: integer, b: integer)"
 end
 # this should never be shown with go2
 def go
  33
 end
 # some suh-weet rdoc
 def self.go2
   34
 end
end

class B
 def self.go2
    35
 end
end

=begin
doctest: should parse funky inspect classes [railsy], too

doctest_require: '../lib/method_desc'
>> A.desc_method(:go, :want_output => true).join('..')
>> A.desc_method(:go2, :want_output => true).join('..')
>> B.desc_method(:go2, :want_output => true).join('..').include?('35')
=> true
>> RUBY_VERSION < '1.9' || A.desc_method(:go2, :want_output => true).join('..').include?('suh-weet rdoc')
=> true
>> A.desc_method(:go2, :want_output => true).join('..').include? 'never be shown'
=> false
=end 
