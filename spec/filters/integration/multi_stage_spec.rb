# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"

module LogStash::Environment
  # running mutate which depends on grok  outside a logstash package means
  # LOGSTASH_HOME will not be defined, so let's set it here
  # before requiring the grok filter
  unless self.const_defined?(:LOGSTASH_HOME)
    LOGSTASH_HOME = File.expand_path("../../../", __FILE__)
  end

  # also :pattern_path method must exist (due grok filter)
  unless self.method_defined?(:pattern_path)
    def pattern_path(path)
      ::File.join(LOGSTASH_HOME, "patterns", path)
    end
  end
end

describe 'LogStash::Filters::Mutate' do

  context 'MUTATE-33: multi stage with json, grok and mutate, Case mutation' do
    let(:config) do
      <<-CONFIG
    filter {
      grok {
        match => { "message" => "(?:hello) %{WORD:bar}" }
        break_on_match => false
      }
      mutate {
        lowercase => [ "bar", "lower1", "lower2" ]
      }
    }
CONFIG
    end

    sample({"message" => "hello WORLD", "lower1" => "PPQQRRSS", "lower2" => "pppqqq"}) do
      result = results.first
      expect(result.get("bar")).to eq('world')
      expect(result.get("lower1")).to eq("ppqqrrss")
      expect(result.get("lower2")).to eq("pppqqq")
    end

  end
end
