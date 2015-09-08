# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/mutate"

# running mutate which depends on grok  outside a logstash package means
# LOGSTASH_HOME will not be defined, so let's set it here
# before requiring the grok filter
unless LogStash::Environment.const_defined?(:LOGSTASH_HOME)
  LogStash::Environment::LOGSTASH_HOME = File.expand_path("../../../", __FILE__)
end


describe LogStash::Filters::Mutate do

  let(:config) { {} }
  subject      { LogStash::Filters::Mutate.new(config) }

  let(:attrs) { { } }
  let(:event) { LogStash::Event.new(attrs) }

  before(:each) do
    subject.register
  end

  context "when doing uppercase of an array" do

    let(:config) do
      { "uppercase" => ["array_of"] }
    end

    let(:attrs) { { "array_of" => ["a", 2, "C"] } }

    it "should uppercase not raise an error" do
      expect { subject.filter(event) }.not_to raise_error
    end

    it "should convert only string elements" do
      subject.filter(event)
      expect(event["array_of"]).to eq(["A", 2, "C"])
    end
  end

  context "when doing lowercase of an array" do

    let(:config) do
      { "lowercase" => ["array_of"] }
    end

    let(:attrs) { { "array_of" => ["a", 2, "C"] } }

    it "should lowercase all string elements" do
      expect { subject.filter(event) }.not_to raise_error
    end

    it "should convert only string elements" do
      subject.filter(event)
      expect(event["array_of"]).to eq(["a", 2, "c"])
    end
  end

end

describe LogStash::Filters::Mutate do

  context "config validation" do
   describe "invalid convert type should raise a configuration error" do
      config <<-CONFIG
        filter {
          mutate {
            convert => [ "message", "int"] //should be integer
          }
        }
      CONFIG

      sample "not_really_important" do
        expect {subject}.to raise_error LogStash::ConfigurationError
      end
    end
    describe "invalid gsub triad should raise a configuration error" do
      config <<-CONFIG
        filter {
          mutate {
            gsub => [ "message", "toreplace"]
          }
        }
      CONFIG

      sample "not_really_important" do
        expect {subject}.to raise_error LogStash::ConfigurationError
      end
    end
  end

  describe "basics" do
    config <<-CONFIG
      filter {
        mutate {
          lowercase => ["lowerme","Lowerme", "lowerMe"]
          uppercase => ["upperme", "Upperme", "upperMe"]
          convert => [ "intme", "integer", "floatme", "float" ]
          rename => [ "rename1", "rename2" ]
          replace => [ "replaceme", "hello world" ]
          replace => [ "newfield", "newnew" ]
          update => [ "nosuchfield", "weee" ]
          update => [ "updateme", "updated" ]
          remove => [ "removeme" ]
        }
      }
    CONFIG

    event = {
      "lowerme" => "example",
      "upperme" => "EXAMPLE",
      "Lowerme" => "ExAmPlE",
      "Upperme" => "ExAmPlE",
      "lowerMe" => [ "ExAmPlE", "example" ],
      "upperMe" => [ "ExAmPlE", "EXAMPLE" ],
      "intme" => [ "1234", "7890.4", "7.9" ],
      "floatme" => [ "1234.455" ],
      "rename1" => [ "hello world" ],
      "updateme" => [ "who cares" ],
      "replaceme" => [ "who cares" ],
      "removeme" => [ "something" ]
    }

    sample event do
      expect(subject["lowerme"]).to eq 'example'
      expect(subject["upperme"]).to eq 'EXAMPLE'
      expect(subject["Lowerme"]).to eq 'example'
      expect(subject["Upperme"]).to eq 'EXAMPLE'
      expect(subject["lowerMe"]).to eq ['example', 'example']
      expect(subject["upperMe"]).to eq ['EXAMPLE', 'EXAMPLE']
      expect(subject["intme"] ).to eq [1234, 7890, 7]
      expect(subject["floatme"]).to eq [1234.455]
      expect(subject).not_to include("rename1")
      expect(subject["rename2"]).to eq [ "hello world" ]
      expect(subject).not_to include("removeme")

      expect(subject).to include("newfield")
      expect(subject["newfield"]).to eq "newnew"
      expect(subject).not_to include("nosuchfield")
      expect(subject["updateme"]).to eq "updated"
    end
  end

  describe "case handling of multibyte unicode strings will only change ASCII" do
    config <<-CONFIG
      filter {
        mutate {
          lowercase => ["lowerme"]
          uppercase => ["upperme"]
        }
      }
    CONFIG

    event = {
      "lowerme" => [ "АБВГД\0MMM", "こにちわ", "XyZółć", "NÎcË GÛŸ"],
      "upperme" => [ "аБвгд\0mmm", "こにちわ", "xYzółć", "Nîcë gûÿ"],
    }

    sample event do
      # ATM, only the ASCII characters will case change
      expect(subject["lowerme"]).to eq [ "АБВГД\0mmm", "こにちわ", "xyzółć", "nÎcË gÛŸ"]
      expect(subject["upperme"]).to eq [ "аБвгд\0MMM", "こにちわ", "XYZółć", "NîCë Gûÿ"]
    end
  end

  describe "remove multiple fields" do
    config '
      filter {
        mutate {
          remove => [ "remove-me", "remove-me2", "diedie", "[one][two]" ]
        }
      }'

    sample(
      "remove-me"  => "Goodbye!",
      "remove-me2" => 1234,
      "diedie"     => [1, 2, 3, 4],
      "survivor"   => "Hello.",
      "one" => { "two" => "wee" }
    ) do
      expect(subject["survivor"]).to eq "Hello."

      expect(subject).not_to include("remove-me")
      expect(subject).not_to include("remove-me2")
      expect(subject).not_to include("diedie")
      expect(subject["one"]).not_to include("two")
    end
  end

  describe "remove on non-existent field" do
    config '
      filter {
        mutate {
          remove => "[foo][bar]"
        }
      }'

    sample(
       "abc"  => "def"
    ) do
      insist { subject["abc"] } == "def"
    end
  end
  

  describe "remove with dynamic fields (%{})" do
    config '
      filter {
        mutate {
          remove => [ "field_%{x}" ]
        }
      }'

    sample(
      "x" => "one",
      "field_one" => "value"
    ) do
      reject { subject }.include?("field_one")
    end
  end

  describe "convert one field to string" do
    config '
      filter {
        mutate {
          convert => [ "unicorns", "string" ]
        }
      }'

    sample("unicorns" => 1234) do
      expect(subject["unicorns"]).to eq "1234"
    end
  end

  describe "convert strings to boolean values" do
    config <<-CONFIG
      filter {
        mutate {
          convert => { "true_field"  => "boolean" }
          convert => { "false_field" => "boolean" }
          convert => { "true_upper"  => "boolean" }
          convert => { "false_upper" => "boolean" }
          convert => { "true_one"    => "boolean" }
          convert => { "false_zero"  => "boolean" }
          convert => { "true_yes"    => "boolean" }
          convert => { "false_no"    => "boolean" }
          convert => { "true_y"      => "boolean" }
          convert => { "false_n"     => "boolean" }
          convert => { "wrong_field" => "boolean" }
        }
      }
    CONFIG
    event = {
      "true_field"  => "true",
      "false_field" => "false",
      "true_upper"  => "True",
      "false_upper" => "False",
      "true_one"    => "1",
      "false_zero"  => "0",
      "true_yes"    => "yes",
      "false_no"    => "no",
      "true_y"      => "Y",
      "false_n"     => "N",
      "wrong_field" => "none of the above"
    }
    sample event do
      expect(subject["true_field"] ).to eq(true)
      expect(subject["false_field"]).to eq(false)
      expect(subject["true_upper"] ).to eq(true)
      expect(subject["false_upper"]).to eq(false)
      expect(subject["true_one"]   ).to eq(true)
      expect(subject["false_zero"] ).to eq(false)
      expect(subject["true_yes"]   ).to eq(true)
      expect(subject["false_no"]   ).to eq(false)
      expect(subject["true_y"]     ).to eq(true)
      expect(subject["false_n"]    ).to eq(false)
      expect(subject["wrong_field"]).to eq("none of the above")
    end
  end

  describe "gsub on a String" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns", "but extinct", "and common" ]
        }
      }'

    sample("unicorns" => "Magnificient, but extinct, animals") do
      expect(subject["unicorns"]).to eq "Magnificient, and common, animals"
    end
  end

  describe "gsub on an Array of Strings" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns", "extinct", "common" ]
        }
      }'

    sample("unicorns" => [
      "Magnificient extinct animals", "Other extinct ideas" ]
    ) do
      expect(subject["unicorns"]).to eq [
        "Magnificient common animals",
        "Other common ideas"
      ]
    end
  end

  describe "gsub on multiple fields" do
    config '
      filter {
        mutate {
          gsub => [ "colors", "red", "blue",
                    "shapes", "square", "circle" ]
        }
      }'

    sample("colors" => "One red car", "shapes" => "Four red squares") do
      expect(subject["colors"]).to eq "One blue car"
      expect(subject["shapes"]).to eq "Four red circles"
    end
  end

  describe "gsub on regular expression" do
    config '
      filter {
        mutate {
          gsub => [ "colors", "\d$", "blue"]
        }
      }'

    sample("colors" => "red3") do
      expect(subject["colors"]).to eq "redblue"
    end
  end

  describe "regression - mutate should lowercase a field created by grok" do
    config <<-CONFIG
      filter {
        grok {
          match => { "message" => "%{WORD:foo}" }
        }
        mutate {
          lowercase => "foo"
        }
      }
    CONFIG

    sample "HELLO WORLD" do
      expect(subject["foo"]).to eq "hello"
    end
  end

  describe "LOGSTASH-757: rename should do nothing with a missing field" do
    config <<-CONFIG
      filter {
        mutate {
          rename => [ "nosuchfield", "hello" ]
        }
      }
    CONFIG

    sample "whatever" do
      expect(subject).not_to include("nosuchfield")
      expect(subject).not_to include("hello")
    end
  end

  describe "rename with dynamic origin field (%{})" do
    config <<-CONFIG
      filter {
        mutate {
          rename => [ "field_%{x}", "destination" ]
        }
      }
    CONFIG

    sample("field_one" => "value", "x" => "one") do
      reject { subject }.include?("field_one")
      insist { subject }.include?("destination")
    end
  end

  describe "rename with dynamic destination field (%{})" do
    config <<-CONFIG
      filter {
        mutate {
          rename => [ "origin", "field_%{x}" ]
        }
      }
    CONFIG

    sample("field_one" => "value", "x" => "one") do
      reject { subject }.include?("origin")
      insist { subject }.include?("field_one")
    end
  end

  describe "convert should work on nested fields" do
    config <<-CONFIG
      filter {
        mutate {
          convert => [ "[foo][bar]", "integer" ]
        }
      }
    CONFIG

    sample({ "foo" => { "bar" => "1000" } }) do
      expect(subject["[foo][bar]"]).to eq 1000
      expect(subject["[foo][bar]"]).to be_a(Fixnum)
    end
  end

  describe "convert should work within arrays" do
    config <<-CONFIG
      filter {
        mutate {
          convert => [ "[foo][0]", "integer" ]
        }
      }
    CONFIG

    sample({ "foo" => ["100", "200"] }) do
      expect(subject["[foo][0]"]).to eq 100
      expect(subject["[foo][0]"]).to be_a(Fixnum)
    end
  end

  #LOGSTASH-1529
  describe "gsub on a String with dynamic fields (%{}) in pattern" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns", "of type %{unicorn_type}", "green" ]
        }
      }'

    sample("unicorns" => "Unicorns of type blue are common", "unicorn_type" => "blue") do
      expect(subject["unicorns"]).to eq "Unicorns green are common"
    end
  end

  #LOGSTASH-1529
  describe "gsub on a String with dynamic fields (%{}) in pattern and replace" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns2", "of type %{unicorn_color}", "%{unicorn_color} and green" ]
        }
      }'

    sample("unicorns2" => "Unicorns of type blue are common", "unicorn_color" => "blue") do
      expect(subject["unicorns2"]).to eq "Unicorns blue and green are common"
    end
  end

  #LOGSTASH-1529
  describe "gsub on a String array with dynamic fields in pattern" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns_array", "of type %{color}", "blue and green" ]
        }
      }'

    sample("unicorns_array" => [
        "Unicorns of type blue are found in Alaska", "Unicorns of type blue are extinct" ],
           "color" => "blue"
    ) do
      expect(subject["unicorns_array"]).to eq [
          "Unicorns blue and green are found in Alaska",
          "Unicorns blue and green are extinct"
      ]
    end
  end

  describe "merge string field into inexisting field" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => "bar") do
      expect(subject["list"]).to eq ["bar"]
      expect(subject["foo"]).to eq "bar"
    end
  end

  describe "merge string field into empty array" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => "bar", "list" => []) do
      expect(subject["list"]).to eq ["bar"]
      expect(subject["foo"]).to eq "bar"
    end
  end

  describe "merge string field into existing array" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => "bar", "list" => ["baz"]) do
      expect(subject["list"]).to eq ["baz", "bar"]
      expect(subject["foo"]).to eq "bar"
    end
  end

  describe "merge non empty array field into existing array" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => ["bar"], "list" => ["baz"]) do
      expect(subject["list"]).to eq ["baz", "bar"]
      expect(subject["foo"]).to eq ["bar"]
    end
  end

  describe "merge empty array field into existing array" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => [], "list" => ["baz"]) do
      expect(subject["list"]).to eq ["baz"]
      expect(subject["foo"]).to eq []
    end
  end

  describe "merge array field into string field" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => ["bar"], "list" => "baz") do
      expect(subject["list"]).to eq ["baz", "bar"]
      expect(subject["foo"]).to eq ["bar"]
    end
  end

  describe "merge string field into string field" do
    config '
      filter {
        mutate {
          merge => [ "list", "foo" ]
        }
      }'

    sample("foo" => "bar", "list" => "baz") do
      expect(subject["list"]).to eq ["baz", "bar"]
      expect(subject["foo"]).to eq "bar"
    end
  end

end
