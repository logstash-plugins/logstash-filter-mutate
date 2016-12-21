# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/mutate"

# running mutate which depends on grok  outside a logstash package means
# LOGSTASH_HOME will not be defined, so let's set it here
# before requiring the grok filter
unless LogStash::Environment.const_defined?(:LOGSTASH_HOME)
  LogStash::Environment::LOGSTASH_HOME = File.expand_path("../../../", __FILE__)
end

# temporary fix to have the spec pass for an urgen mass-publish requirement.
# cut & pasted from the same tmp fix in the grok spec
# see https://github.com/logstash-plugins/logstash-filter-grok/issues/72
# this needs to be refactored and properly fixed
module LogStash::Environment
  # also :pattern_path method must exist so we define it too
  unless self.method_defined?(:pattern_path)
    def pattern_path(path)
      ::File.join(LOGSTASH_HOME, "patterns", path)
    end
  end
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
      expect(event.get("array_of")).to eq(["A", 2, "C"])
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
      expect(event.get("array_of")).to eq(["a", 2, "c"])
    end
  end

  %w(lowercase uppercase).each do |operation|
    context "executing #{operation} a non-existant field" do
      let(:attrs) { }

      let(:config) do
        { operation => ["fake_field"] }
      end

      it "should not create that field" do
        subject.filter(event)
        expect(event).not_to include("fake_field")
      end
    end
  end
end

describe LogStash::Filters::Mutate do

  let(:config) { {} }
  subject      { LogStash::Filters::Mutate.new(config) }

  let(:attrs) { { } }
  let(:event) { LogStash::Event.new(attrs) }

  before(:each) do
    subject.register
  end

  describe "#strip" do

    let(:config) do
      { "strip" => ["path"] }
    end

    let(:attrs) { { "path" => " /store.php " } }

    it "should cleam trailing spaces" do
      subject.filter(event)
      expect(event.get("path")).to eq("/store.php")
    end

    context "when converting multiple attributed at once" do

      let(:config) do
        { "strip" => ["foo", "bar"] }
      end

      let(:attrs) { { "foo" => " /bar.php ", "bar" => " foo" } }

      it "should cleam trailing spaces" do
        subject.filter(event)
        expect(event.get("foo")).to eq("/bar.php")
        expect(event.get("bar")).to eq("foo")
      end
    end
  end

  describe "#split" do

    let(:config) do
      { "split" => {"field" => "," } }
    end

    context "when source field is a string" do

      let(:attrs) { { "field" => "foo,bar,baz" } }

      it "should split string into array" do
        subject.filter(event)
        expect(event.get("field")).to eq(["foo","bar","baz"])
      end

      it "should convert single field to array" do
        event.set("field","foo")
        subject.filter(event)
        expect(event.get("field")).to eq(["foo"])

        event.set("field","foo,")
        subject.filter(event)
        expect(event.get("field")).to eq(["foo"])
      end

    end

    context "when source field is not a string" do

      it "should not modify source field nil" do
        event.set("field",nil)
        subject.filter(event)
        expect(event.get("field")).to eq(nil)
      end

      it "should not modify source field array" do
        event.set("field",["foo","bar"])
        subject.filter(event)
        expect(event.get("field")).to eq(["foo","bar"])
      end

      it "should not modify source field hash" do
        event.set("field",{"foo" => "bar,baz"})
        subject.filter(event)
        expect(event.get("field")).to eq({"foo" => "bar,baz"})
      end
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
      "replaceme" => [ "who cares" ]
    }

    sample event do
      expect(subject.get("lowerme")).to eq 'example'
      expect(subject.get("upperme")).to eq 'EXAMPLE'
      expect(subject.get("Lowerme")).to eq 'example'
      expect(subject.get("Upperme")).to eq 'EXAMPLE'
      expect(subject.get("lowerMe")).to eq ['example', 'example']
      expect(subject.get("upperMe")).to eq ['EXAMPLE', 'EXAMPLE']
      expect(subject.get("intme") ).to eq [1234, 7890, 7]
      expect(subject.get("floatme")).to eq [1234.455]
      expect(subject).not_to include("rename1")
      expect(subject.get("rename2")).to eq [ "hello world" ]

      expect(subject).to include("newfield")
      expect(subject.get("newfield")).to eq "newnew"
      expect(subject).not_to include("nosuchfield")
      expect(subject.get("updateme")).to eq "updated"
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
      expect(subject.get("lowerme")).to eq [ "АБВГД\0mmm", "こにちわ", "xyzółć", "nÎcË gÛŸ"]
      expect(subject.get("upperme")).to eq [ "аБвгд\0MMM", "こにちわ", "XYZółć", "NîCë Gûÿ"]
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
  

  describe "convert one field to string" do
    config '
      filter {
        mutate {
          convert => [ "unicorns", "string" ]
        }
      }'

    sample("unicorns" => 1234) do
      expect(subject.get("unicorns")).to eq "1234"
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
      expect(subject.get("true_field") ).to eq(true)
      expect(subject.get("false_field")).to eq(false)
      expect(subject.get("true_upper") ).to eq(true)
      expect(subject.get("false_upper")).to eq(false)
      expect(subject.get("true_one")   ).to eq(true)
      expect(subject.get("false_zero") ).to eq(false)
      expect(subject.get("true_yes")   ).to eq(true)
      expect(subject.get("false_no")   ).to eq(false)
      expect(subject.get("true_y")     ).to eq(true)
      expect(subject.get("false_n")    ).to eq(false)
      expect(subject.get("wrong_field")).to eq("none of the above")
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
      expect(subject.get("unicorns")).to eq "Magnificient, and common, animals"
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
      expect(subject.get("unicorns")).to eq [
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
      expect(subject.get("colors")).to eq "One blue car"
      expect(subject.get("shapes")).to eq "Four red circles"
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
      expect(subject.get("colors")).to eq "redblue"
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
      expect(subject.get("foo")).to eq "hello"
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
      expect(subject.get("[foo][bar]")).to eq 1000
      expect(subject.get("[foo][bar]")).to be_a(Fixnum)
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
      expect(subject.get("[foo][0]")).to eq 100
      expect(subject.get("[foo][0]")).to be_a(Fixnum)
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
      expect(subject.get("unicorns")).to eq "Unicorns green are common"
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
      expect(subject.get("unicorns2")).to eq "Unicorns blue and green are common"
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
      expect(subject.get("unicorns_array")).to eq [
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
      expect(subject.get("list")).to eq ["bar"]
      expect(subject.get("foo")).to eq "bar"
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
      expect(subject.get("list")).to eq ["bar"]
      expect(subject.get("foo")).to eq "bar"
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
      expect(subject.get("list")).to eq ["baz", "bar"]
      expect(subject.get("foo")).to eq "bar"
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
      expect(subject.get("list")).to eq ["baz", "bar"]
      expect(subject.get("foo")).to eq ["bar"]
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
      expect(subject.get("list")).to eq ["baz"]
      expect(subject.get("foo")).to eq []
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
      expect(subject.get("list")).to eq ["baz", "bar"]
      expect(subject.get("foo")).to eq ["bar"]
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
      expect(subject.get("list")).to eq ["baz", "bar"]
      expect(subject.get("foo")).to eq "bar"
    end
  end

end
