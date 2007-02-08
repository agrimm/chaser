#!/usr/bin/env ruby

require 'test/unit/autorunner'
require 'heckle'
$: << 'lib' << 'test'

class TestUnitHeckler < Heckle
  @@test_pattern = 'test/test_*.rb'
  @@tests_loaded = false;

  def self.test_pattern=(value)
    @@test_pattern = value
  end

  def self.load_test_files
    @@tests_loaded = true
    Dir.glob(@@test_pattern).each {|test| require test}
  end

  def self.validate(klass_name, method_name = nil)
    load_test_files
    klass = klass_name.to_class

    # Does the method exist?
    klass_methods = klass.singleton_methods(false).collect {|meth| "self.#{meth}"}
    if method_name
      if method_name =~ /self\./
        abort "Unknown method: #{klass_name}.#{method_name.gsub('self.', '')}" unless klass_methods.include? method_name
      else
        abort "Unknown method: #{klass_name}##{method_name}" unless klass.instance_methods(false).include? method_name
      end
    end

    initial_time = Time.now

    unless self.new(klass_name).tests_pass? then
      abort "Initial run of tests failed... fix and run heckle again"
    end

    if self.guess_timeout?
      running_time = (Time.now - initial_time)
      adjusted_timeout = (running_time * 2 < 5) ? 5 : (running_time * 2)
      self.timeout = adjusted_timeout
      puts "Setting timeout at #{adjusted_timeout} seconds." if @@debug

    end

    self.timeout = adjusted_timeout

    puts "Initial tests pass. Let's rumble."
    puts

    methods = method_name ? Array(method_name) : klass.instance_methods(false) + klass_methods

    counts = Hash.new(0)
    methods.sort.each do |method_name|
      result = self.new(klass_name, method_name).validate
      counts[result] += 1
    end
    all_good = counts[false] == 0

    puts "Heckle Results:"
    puts
    puts "Passed    : %3d" % counts[true]
    puts "Failed    : %3d" % counts[false]
    puts "Thick Skin: %3d" % counts[nil]
    puts

    if all_good then
      puts "All heckling was thwarted! YAY!!!"
    else
      puts "Improve the tests and try again."
    end

    all_good
  end

  def initialize(klass_name=nil, method_name=nil)
    super(klass_name, method_name)
    self.class.load_test_files unless @@tests_loaded
  end

  def tests_pass?
    silence_stream do
      Test::Unit::AutoRunner.run
    end
  end
end
