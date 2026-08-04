# frozen_string_literal: true

# The regression this gem shipped: PgCron::Statements and Fx::Statements are both
# included into ActiveRecord::ConnectionAdapters::AbstractAdapter, and every
# private helper here was lifted from F(x) under F(x)'s own name. We are included
# second, so ours won — and `resolve_sql_definition` takes one argument fewer
# than F(x)'s, which meant that merely loading this gem broke create_function,
# create_trigger and update_function in the HOST application:
#
#   ArgumentError: wrong number of arguments (given 4, expected 3)
#
# The fix is that our private helpers are named `*_cron_*`. This is the test that
# says so, and it needs no database — the bug was in method lookup, not in SQL.
#
# Deliberately checks the whole intersection rather than that one method. The
# next helper copied across from F(x) is the next outage, and only a test of the
# INTERSECTION catches one that has not been written yet.
require "active_support/all"
require "pg_cron/statements"
require "fx/statements"

RSpec.describe "PgCron::Statements alongside Fx::Statements" do
  # Both modules are mixed into one object, so any shared name is a collision —
  # whichever include lands second silently replaces the other's method.
  def shared_instance_methods(visibility)
    ours   = PgCron::Statements.send(:"#{visibility}_instance_methods", false)
    theirs = Fx::Statements.send(:"#{visibility}_instance_methods", false)
    ours & theirs
  end

  it "shares no public method name with F(x)" do
    expect(shared_instance_methods(:public)).to be_empty
  end

  it "shares no private method name with F(x)" do
    expect(shared_instance_methods(:private)).to be_empty
  end

  # The end the user actually feels: with both modules in, in the order the
  # railties install them, F(x)'s statements still reach F(x)'s implementation.
  it "leaves F(x)'s statements callable when included second" do
    adapter = Class.new do
      include Fx::Statements
      include PgCron::Statements # second, as the railtie does it
    end.new

    # F(x)'s four-argument private helper, reached through F(x)'s own method
    # lookup. Before the rename this raised ArgumentError here.
    expect {
      adapter.send(:resolve_sql_definition, "SELECT 1;\n", :whatever, 1, :function)
    }.not_to raise_error
  end
end
