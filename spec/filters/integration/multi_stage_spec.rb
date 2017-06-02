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
  let(:pipeline) do
    new_pipeline_from_string(config)
  end

  let(:events) do
    arr = event.is_a?(Array) ? event : [event]
    arr.map do |evt|
      LogStash::Event.new(evt.is_a?(String) ? LogStash::Json.load(evt) : evt)
    end
  end

  let(:results) do
    pipeline.instance_eval { @filters.each(&:register) }
    results  = []
    events.each do |evt|
      # filter call the block on all filtered events, included new events added by the filter
      pipeline.filter(evt) do |filtered_event|
        results.push(filtered_event)
      end
    end
    pipeline.flush_filters(:final => true) { |flushed_event| results << flushed_event }

    results.select { |e| !e.cancelled? }
  end

  describe 'MUTATE-33: multi stage with json, grok and mutate, Case mutation' do
    let(:event) do
      "{\"message\":\"hello WORLD\",\"lower1\":\"PPQQRRSS\",\"lower2\":\"pppqqq\"}"
    end

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

    it 'change case of the target, bar value is lowercase' do
      result = results.first
      expect(result.get("bar")).to eq('world')
    end

    it 'change case of the target, lower1 value is lowercase' do
      result = results.first
      expect(result.get("lower1")).to eq("ppqqrrss")
    end

    it 'change case of the target, lower2 value is lowercase' do
      result = results.first
      expect(result.get("lower2")).to eq("pppqqq")
    end

  end
end
