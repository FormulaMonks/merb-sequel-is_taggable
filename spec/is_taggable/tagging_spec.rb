require File.dirname(__FILE__) + '/../spec_helper'

describe Tagging do
  before(:each) do
    @tagging = Tagging.new
  end

  it "should require a tag" do
    @tagging.valid?
    @tagging.should have(1).errors_on(:tag)
  end
  
  it "should require a normalized version of the tag" do
    @tagging.valid?
    @tagging.should have(1).errors_on(:normalized)
  end
  
  it "should be valid with a tag" do
    @tagging.tag = "something"
    @tagging.valid?
    @tagging.should have(0).errors_on(:tag)
  end
  
  it "should return its name when to_s is called" do
    @tagging.tag = "cool"
    @tagging.to_s.should == "cool"
  end
  
  it "should raise if you try to save one even when it's valid" do
    @tagging.tag = 'foo'
    lambda { @tagging.save }.should raise_error
  end
end
