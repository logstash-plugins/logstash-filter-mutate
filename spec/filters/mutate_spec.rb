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

logstash_version = Gem::Version.create(LOGSTASH_CORE_VERSION)

if (Gem::Requirement.create('~> 7.0').satisfied_by?(logstash_version) ||
   (Gem::Requirement.create('~> 6.4').satisfied_by?(logstash_version) && LogStash::SETTINGS.get('config.field_reference.parser') == 'STRICT'))
  describe LogStash::Filters::Mutate do
    let(:config) { Hash.new }
    subject(:mutate_filter) { LogStash::Filters::Mutate.new(config) }

    before(:each) { mutate_filter.register }

    let(:event) { LogStash::Event.new(attrs) }

    context 'when operation would cause an error' do

      let(:invalid_field_name) { "[[][[[[]message" }
      let(:config) do
        super().merge("add_field" => {invalid_field_name => "nope"})
      end

      shared_examples('catch and tag error') do
        let(:expected_tag) { '_mutate_error' }

        let(:event) { LogStash::Event.new({"message" => "foo"})}

        context 'when the event is filtered' do
          before(:each) { mutate_filter.filter(event) }
          it 'does not raise an exception' do
            # noop
          end

          it 'tags the event with the expected tag' do
            expect(event).to include('tags')
            expect(event.get('tags')).to include(expected_tag)
          end
        end
      end

      context 'when `tag_on_failure` is not provided' do
        include_examples 'catch and tag error'
      end

      context 'when `tag_on_failure` is provided' do
        include_examples 'catch and tag error' do
          let(:expected_tag) { 'my_custom_tag' }
          let(:config) { super().merge('tag_on_failure' => expected_tag) }
        end
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

  context "when doing capitalize of an array" do

    let(:config) do
      { "capitalize" => ["array_of"] }
    end

    let(:attrs) { { "array_of" => ["ab", 2, "CDE"] } }

    it "should capitalize not raise an error" do
      expect { subject.filter(event) }.not_to raise_error
    end

    it "should convert only string elements" do
      subject.filter(event)
      expect(event.get("array_of")).to eq(["Ab", 2, "Cde"])
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

  %w(lowercase uppercase capitalize).each do |operation|
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
    context "avoid mutating contents of field, as they may be shared" do
      let(:original_value) { "oRiGiNaL vAlUe".freeze }
      let(:shared_value) { original_value.dup }
      let(:attrs) { {"field" => shared_value } }
      let(:config) do
        {
          operation => "field"
        }
      end

      it 'should not mutate the value' do
        subject.filter(event)
        expect(shared_value).to eq(original_value)
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

  describe "#copy" do

    let(:config) do
      { "copy" => {"field" => "target" } }
    end

    context "when source field is a string" do

      let(:attrs) { { "field" => "foobar" } }

      it "should deep copy the field" do
        subject.filter(event)
        expect(event.get("target")).to eq(event.get("field"))
        #fields should be independant
        event.set("field",nil);
        expect(event.get("target")).not_to eq(event.get("field"))
      end
    end

    context "when source field is an array" do

      let(:attrs) { { "field" => ["foo","bar"] } }

      it "should not modify source field nil" do
        subject.filter(event)
        expect(event.get("target")).to eq(event.get("field"))
        #fields should be independant
        event.set("field",event.get("field") << "baz")
        expect(event.get("target")).not_to eq(event.get("field"))
      end
    end

    context "when source field is a hash" do

      let(:attrs) { { "field" => { "foo" => "bar"} } }

      it "should not modify source field nil" do
        subject.filter(event)
        expect(event.get("target")).to eq(event.get("field"))
        #fields should be independant
        event.set("[field][foo]","baz")
        expect(event.get("[target][foo]")).not_to eq(event.get("[field][foo]"))
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
            convert => [ "message", "int"] #should be integer
          }
        }
      CONFIG

      sample "not_really_important" do
        expect {subject}.to raise_error(LogStash::ConfigurationError, /Invalid conversion type/)
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
        expect {subject}.to raise_error(LogStash::ConfigurationError, /Invalid gsub configuration/)
      end
    end
  end

  describe "basics" do
    config <<-CONFIG
      filter {
        mutate {
          lowercase => ["lowerme","Lowerme", "lowerMe"]
          uppercase => ["upperme", "Upperme", "upperMe"]
          capitalize => ["capitalizeme", "Capitalizeme", "capitalizeMe"]
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
      "capitalizeme" => "Example",
      "Lowerme" => "ExAmPlE",
      "Upperme" => "ExAmPlE",
      "Capitalizeme" => "ExAmPlE",
      "lowerMe" => [ "ExAmPlE", "example" ],
      "upperMe" => [ "ExAmPlE", "EXAMPLE" ],
      "capitalizeMe" => [ "ExAmPlE", "Example" ],
      "intme" => [ "1234", "7890.4", "7.9" ],
      "floatme" => [ "1234.455" ],
      "rename1" => [ "hello world" ],
      "updateme" => [ "who cares" ],
      "replaceme" => [ "who cares" ]
    }

    sample event do
      expect(subject.get("lowerme")).to eq 'example'
      expect(subject.get("upperme")).to eq 'EXAMPLE'
      expect(subject.get("capitalizeme")).to eq 'Example'
      expect(subject.get("Lowerme")).to eq 'example'
      expect(subject.get("Upperme")).to eq 'EXAMPLE'
      expect(subject.get("Capitalizeme")).to eq 'Example'
      expect(subject.get("lowerMe")).to eq ['example', 'example']
      expect(subject.get("upperMe")).to eq ['EXAMPLE', 'EXAMPLE']
      expect(subject.get("capitalizeMe")).to eq ['Example', 'Example']
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
          capitalize => ["capitalizeme"]
        }
      }
    CONFIG

    event = {
      "lowerme" => [ "АБВГД\0MMM", "こにちわ", "XyZółć", "NÎcË GÛŸ"],
      "upperme" => [ "аБвгд\0mmm", "こにちわ", "xYzółć", "Nîcë gûÿ"],
      "capitalizeme" => ["АБВГД\0mmm", "こにちわ", "xyzółć", "nÎcË gÛŸ"],
    }

    sample event do
      expect(subject.get("lowerme")).to eq [ "абвгд\0mmm", "こにちわ", "xyzółć", "nîcë gûÿ"]
      expect(subject.get("upperme")).to eq [ "АБВГД\0MMM", "こにちわ", "XYZÓŁĆ", "NÎCË GÛŸ"]
      expect(subject.get("capitalizeme")).to eq [ "Абвгд\0mmm", "こにちわ", "Xyzółć", "Nîcë gûÿ"]
    end
  end

  describe "convert one field to string" do
    config '
      filter {
        mutate {
          convert => [ "unicorns", "string" ]
        }
      }'

    sample({"unicorns" => 1234}) do
      expect(subject.get("unicorns")).to eq "1234"
    end
  end

  describe "convert strings to boolean values" do
    config <<-CONFIG
      filter {
        mutate {
          convert => { "true_field"         => "boolean" }
          convert => { "false_field"        => "boolean" }
          convert => { "true_upper"         => "boolean" }
          convert => { "false_upper"        => "boolean" }
          convert => { "true_one"           => "boolean" }
          convert => { "false_zero"         => "boolean" }
          convert => { "true_yes"           => "boolean" }
          convert => { "false_no"           => "boolean" }
          convert => { "true_y"             => "boolean" }
          convert => { "false_n"            => "boolean" }
          convert => { "wrong_field"        => "boolean" }
          convert => { "integer_false"      => "boolean" }
          convert => { "integer_true"       => "boolean" }
          convert => { "integer_negative"   => "boolean" }
          convert => { "integer_wrong"      => "boolean" }
          convert => { "float_true"         => "boolean" }
          convert => { "float_false"        => "boolean" }
          convert => { "float_negative"     => "boolean" }
          convert => { "float_wrong"        => "boolean" }
          convert => { "float_wrong2"       => "boolean" }
          convert => { "array"              => "boolean" }
          convert => { "hash"               => "boolean" }
        }
      }
    CONFIG
    event = {
      "true_field"      => "true",
      "false_field"     => "false",
      "true_upper"      => "True",
      "false_upper"     => "False",
      "true_one"        => "1",
      "false_zero"      => "0",
      "true_yes"        => "yes",
      "false_no"        => "no",
      "true_y"          => "Y",
      "false_n"         => "N",
      "wrong_field"     => "none of the above",
      "integer_false"   => 0,
      "integer_true"    => 1,
      "integer_negative"=> -1,
      "integer_wrong"   => 2,
      "float_true"      => 1.0,
      "float_false"     => 0.0,
      "float_negative"  => -1.0,
      "float_wrong"     => 1.0123,
      "float_wrong2"    => 0.01,
      "array"           => [ "1", "0", 0,1,2],
      "hash"            => { "a" => 0 }
    }
    sample event do
      expect(subject.get("true_field")      ).to eq(true)
      expect(subject.get("false_field")     ).to eq(false)
      expect(subject.get("true_upper")      ).to eq(true)
      expect(subject.get("false_upper")     ).to eq(false)
      expect(subject.get("true_one")        ).to eq(true)
      expect(subject.get("false_zero")      ).to eq(false)
      expect(subject.get("true_yes")        ).to eq(true)
      expect(subject.get("false_no")        ).to eq(false)
      expect(subject.get("true_y")          ).to eq(true)
      expect(subject.get("false_n")         ).to eq(false)
      expect(subject.get("wrong_field")     ).to eq("none of the above")
      expect(subject.get("integer_false")   ).to eq(false)
      expect(subject.get("integer_true")    ).to eq(true)
      expect(subject.get("integer_negative")).to eq(-1)
      expect(subject.get("integer_wrong")   ).to eq(2)
      expect(subject.get("float_true")      ).to eq(true)
      expect(subject.get("float_false")     ).to eq(false)
      expect(subject.get("float_negative")  ).to eq(-1.0)
      expect(subject.get("float_wrong")     ).to eq(1.0123)
      expect(subject.get("float_wrong2")    ).to eq(0.01)
      expect(subject.get("array")           ).to eq([true, false, false, true,2])
      expect(subject.get("hash")            ).to eq({ "a" => 0 })
    end
  end

  describe "convert to float" do

    config <<-CONFIG
      filter {
        mutate {
          convert => {
            "field" => "float"
          }
        }
      }
    CONFIG

    context 'when field is a string with no separator and dot decimal' do
      sample({'field' => '3141.5926'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.5926)
      end
    end

    context 'when field is a string with a comma separator and dot decimal' do
      sample({'field' => '3,141.5926'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.5926)
      end
    end

    context 'when field is a string comma separator and no decimal' do
      sample({'field' => '3,141'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.0)
      end
    end

    context 'when field is a string no separator and no decimal' do
      sample({'field' => '3141'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.0)
      end
    end

    context 'when field is a float' do
      sample({'field' => 3.1415926}) do
        expect(subject.get('field')).to be_within(0.000001).of(3.1415926)
      end
    end

    context 'when field is an integer' do
      sample({'field' => 3}) do
        expect(subject.get('field')).to be_within(0.000001).of(3)
      end
    end

    context 'when field is the true value' do
      sample({'field' => true}) do
        expect(subject.get('field')).to eq(1.0)
      end
    end

    context 'when field is the false value' do
      sample({'field' => false}) do
        expect(subject.get('field')).to eq(0.0)
      end
    end

    context 'when field is nil' do
      sample({'field' => nil}) do
        expect(subject.get('field')).to be_nil
      end
    end

    context 'when field is not set' do
      sample({'field' => nil}) do
        expect(subject.get('field')).to be_nil
      end
    end
  end


  describe "convert to float_eu" do
    config <<-CONFIG
      filter {
        mutate {
          convert => {
            "field" => "float_eu"
          }
        }
      }
    CONFIG

    context 'when field is a string with no separator and comma decimal' do
      sample({'field' => '3141,5926'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.5926)
      end
    end

    context 'when field is a string with a dot separator and comma decimal' do
      sample({'field' => '3.141,5926'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.5926)
      end
    end

    context 'when field is a string dot separator and no decimal' do
      sample({'field' => '3.141'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.0)
      end
    end

    context 'when field is a string no separator and no decimal' do
      sample({'field' => '3141'}) do
        expect(subject.get('field')).to be_within(0.0001).of(3141.0)
      end
    end

    context 'when field is a float' do
      sample({'field' => 3.1415926}) do
        expect(subject.get('field')).to be_within(0.000001).of(3.1415926)
      end
    end

    context 'when field is an integer' do
      sample({'field' => 3}) do
        expect(subject.get('field')).to be_within(0.000001).of(3)
      end
    end

    context 'when field is the true value' do
      sample({'field' => true}) do
        expect(subject.get('field')).to eq(1.0)
      end
    end

    context 'when field is the false value' do
      sample({'field' => false}) do
        expect(subject.get('field')).to eq(0.0)
      end
    end

    context 'when field is nil' do
      sample({'field' => nil}) do
        expect(subject.get('field')).to be_nil
      end
    end

    context 'when field is not set' do
      sample({'field' => nil}) do
        expect(subject.get('field')).to be_nil
      end
    end
  end

  describe "gsub on a String" do
    config '
      filter {
        mutate {
          gsub => [ "unicorns", "but extinct", "and common" ]
        }
      }'

    sample({"unicorns" => "Magnificient, but extinct, animals"}) do
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

    sample({"unicorns" => [
      "Magnificient extinct animals", "Other extinct ideas" ]}
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

    sample({"colors" => "One red car", "shapes" => "Four red squares"}) do
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

    sample({"colors" => "red3"}) do
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

    sample({"field_one" => "value", "x" => "one"}) do
      expect(subject).to_not include("field_one")
      expect(subject).to include("destination")
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

    sample({"field_one" => "value", "x" => "one"}) do
      expect(subject).to_not include("origin")
      expect(subject).to include("field_one")
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
      expect(subject.get("[foo][bar]")).to be_a(Integer)
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
      expect(subject.get("[foo][0]")).to be_a(Integer)
    end
  end

  describe "convert booleans to integer" do
    config <<-CONFIG
      filter {
        mutate {
          convert => {
            "[foo][0]" => "integer"
            "[foo][1]" => "integer"
            "[foo][2]" => "integer"
            "[foo][3]" => "integer"
            "[foo][4]" => "integer"
          }
        }
      }
    CONFIG

    sample({ "foo" => [false, true, "0", "1", "2"] }) do
      expect(subject.get("[foo][0]")).to eq 0
      expect(subject.get("[foo][0]")).to be_a(Integer)
      expect(subject.get("[foo][1]")).to eq 1
      expect(subject.get("[foo][1]")).to be_a(Integer)
      expect(subject.get("[foo][2]")).to eq 0
      expect(subject.get("[foo][2]")).to be_a(Integer)
      expect(subject.get("[foo][3]")).to eq 1
      expect(subject.get("[foo][3]")).to be_a(Integer)
      expect(subject.get("[foo][4]")).to eq 2
      expect(subject.get("[foo][4]")).to be_a(Integer)
    end
  end

  describe "convert various US/UK strings" do
    describe "to integer" do
      config <<-CONFIG
        filter {
          mutate {
            convert => {
              "[foo][0]" => "integer"
              "[foo][1]" => "integer"
              "[foo][2]" => "integer"
            }
          }
        }
      CONFIG

      sample({ "foo" => ["1,000", "1,234,567.8", "123.4"] }) do
        expect(subject.get("[foo][0]")).to eq 1000
        expect(subject.get("[foo][0]")).to be_a(Integer)
        expect(subject.get("[foo][1]")).to eq 1234567
        expect(subject.get("[foo][1]")).to be_a(Integer)
        expect(subject.get("[foo][2]")).to eq 123
        expect(subject.get("[foo][2]")).to be_a(Integer)
      end
    end

    describe "to float" do
      config <<-CONFIG
        filter {
          mutate {
            convert => {
              "[foo][0]" => "float"
              "[foo][1]" => "float"
              "[foo][2]" => "float"
            }
          }
        }
      CONFIG

      sample({ "foo" => ["1,000", "1,234,567.8", "123.4"] }) do
        expect(subject.get("[foo][0]")).to eq 1000.0
        expect(subject.get("[foo][0]")).to be_a(Float)
        expect(subject.get("[foo][1]")).to eq 1234567.8
        expect(subject.get("[foo][1]")).to be_a(Float)
        expect(subject.get("[foo][2]")).to eq 123.4
        expect(subject.get("[foo][2]")).to be_a(Float)
      end
    end
  end

  describe "convert various EU style strings" do
    describe "to integer" do
      config <<-CONFIG
        filter {
          mutate {
            convert => {
              "[foo][0]" => "integer_eu"
              "[foo][1]" => "integer_eu"
              "[foo][2]" => "integer_eu"
            }
          }
        }
      CONFIG

      sample({ "foo" => ["1.000", "1.234.567,8", "123,4"] }) do
        expect(subject.get("[foo][0]")).to eq 1000
        expect(subject.get("[foo][0]")).to be_a(Integer)
        expect(subject.get("[foo][1]")).to eq 1234567
        expect(subject.get("[foo][1]")).to be_a(Integer)
        expect(subject.get("[foo][2]")).to eq 123
        expect(subject.get("[foo][2]")).to be_a(Integer)
      end
    end

    describe "to float" do
      config <<-CONFIG
        filter {
          mutate {
            convert => {
              "[foo][0]" => "float_eu"
              "[foo][1]" => "float_eu"
              "[foo][2]" => "float_eu"
            }
          }
        }
      CONFIG

      sample({ "foo" => ["1.000", "1.234.567,8", "123,4"] }) do
        expect(subject.get("[foo][0]")).to eq 1000.0
        expect(subject.get("[foo][0]")).to be_a(Float)
        expect(subject.get("[foo][1]")).to eq 1234567.8
        expect(subject.get("[foo][1]")).to be_a(Float)
        expect(subject.get("[foo][2]")).to eq 123.4
        expect(subject.get("[foo][2]")).to be_a(Float)
      end
    end
  end

  describe "convert auto-frozen values to string" do
    config <<-CONFIG
      filter {
        mutate {
          convert => {
            "true_field"  => "string"
            "false_field" => "string"
          }
        }
      }
    CONFIG

    sample({ "true_field" => true, "false_field" => false }) do
      expect(subject.get("true_field")).to eq "true"
      expect(subject.get("true_field")).to be_a(String)
      expect(subject.get("false_field")).to eq "false"
      expect(subject.get("false_field")).to be_a(String)
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

    sample({"unicorns" => "Unicorns of type blue are common", "unicorn_type" => "blue"}) do
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

    sample({"unicorns2" => "Unicorns of type blue are common", "unicorn_color" => "blue"}) do
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

    sample({"unicorns_array" => [
        "Unicorns of type blue are found in Alaska", "Unicorns of type blue are extinct" ],
           "color" => "blue" }
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

    sample({"foo" => "bar"}) do
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

    sample({"foo" => "bar", "list" => []}) do
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

    sample({"foo" => "bar", "list" => ["baz"]}) do
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

    sample({"foo" => ["bar"], "list" => ["baz"]}) do
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

    sample({"foo" => [], "list" => ["baz"]}) do
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

    sample({"foo" => ["bar"], "list" => "baz"}) do
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

    sample({"foo" => "bar", "list" => "baz"}) do
      expect(subject.get("list")).to eq ["baz", "bar"]
      expect(subject.get("foo")).to eq "bar"
    end
  end

  describe "coerce arrays fields with default values when null" do
    config '
      filter {
        mutate {
          coerce => {
            "field1" => "Hello"
            "field2" => "Bye"
            "field3" => 5
            "field4" => false
          }
        }
      }'


    sample({"field1" => nil, "field2" => nil, "field3" => nil, "field4" => true}) do
      expect(subject.get("field1")).to eq("Hello")
      expect(subject.get("field2")).to eq("Bye")
      expect(subject.get("field3")).to eq("5")
      expect(subject.get("field4")).to eq(true)
    end
  end

end
