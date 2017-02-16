# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# The mutate filter allows you to perform general mutations on fields. You
# can rename, remove, replace, and modify fields in your events.
class LogStash::Filters::Mutate < LogStash::Filters::Base
  config_name "mutate"

  # Rename one or more fields.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         # Renames the 'HOSTORIP' field to 'client_ip'
  #         rename => { "HOSTORIP" => "client_ip" }
  #       }
  #     }
  config :rename, :validate => :hash

  # Replace a field with a new value. The new value can include `%{foo}` strings
  # to help you build a new value from other parts of the event.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         replace => { "message" => "%{source_host}: My new message" }
  #       }
  #     }
  config :replace, :validate => :hash

  # Update an existing field with a new value. If the field does not exist,
  # then no action will be taken.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         update => { "sample" => "My new message" }
  #       }
  #     }
  config :update, :validate => :hash

  # Convert a field's value to a different type, like turning a string to an
  # integer. If the field value is an array, all members will be converted.
  # If the field is a hash, no action will be taken.
  #
  # If the conversion type is `boolean`, the acceptable values are:
  #
  # * **True:** `true`, `t`, `yes`, `y`, and `1`
  # * **False:** `false`, `f`, `no`, `n`, and `0`
  #
  # If a value other than these is provided, it will pass straight through
  # and log a warning message.
  #
  # Valid conversion targets are: integer, float, string, and boolean.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         convert => { "fieldname" => "integer" }
  #       }
  #     }
  config :convert, :validate => :hash

  # Convert a string field by applying a regular expression and a replacement.
  # If the field is not a string, no action will be taken.
  #
  # This configuration takes an array consisting of 3 elements per
  # field/substitution.
  #
  # Be aware of escaping any backslash in the config file.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         gsub => [
  #           # replace all forward slashes with underscore
  #           "fieldname", "/", "_",
  #           # replace backslashes, question marks, hashes, and minuses
  #           # with a dot "."
  #           "fieldname2", "[\\?#-]", "."
  #         ]
  #       }
  #     }
  #
  config :gsub, :validate => :array

  # Convert a string to its uppercase equivalent.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         uppercase => [ "fieldname" ]
  #       }
  #     }
  config :uppercase, :validate => :array

  # Convert a string to its lowercase equivalent.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         lowercase => [ "fieldname" ]
  #       }
  #     }
  config :lowercase, :validate => :array

  # Split a field to an array using a separator character. Only works on string
  # fields.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #          split => { "fieldname" => "," }
  #       }
  #     }
  config :split, :validate => :hash

  # Join an array with a separator character. Does nothing on non-array fields.
  #
  # Example:
  # [source,ruby]
  #    filter {
  #      mutate {
  #        join => { "fieldname" => "," }
  #      }
  #    }
  config :join, :validate => :hash

  # Strip whitespace from field. NOTE: this only works on leading and trailing whitespace.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #          strip => ["field1", "field2"]
  #       }
  #     }
  config :strip, :validate => :array

  # Merge two fields of arrays or hashes.
  # String fields will be automatically be converted into an array, so:
  # ==========================
  #   `array` + `string` will work
  #   `string` + `string` will result in an 2 entry array in `dest_field`
  #   `array` and `hash` will not work
  # ==========================
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #          merge => { "dest_field" => "added_field" }
  #       }
  #     }
  config :merge, :validate => :hash

  # Move all properties of a sub-structure of the event to the `target` field (which is the root level if not specified).
  # By default, all the other properties of the target are kept, but it is also possible to erase them by setting `empty_target` to `true`
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #          move => {
  #             "field" => "moved_field"
  #             "target" => "target_field"
  #             "empty_target" => true
  #          }
  #       }
  #     }
  config :move, :validate => :hash

  TRUE_REGEX = (/^(true|t|yes|y|1)$/i).freeze
  FALSE_REGEX = (/^(false|f|no|n|0)$/i).freeze
  CONVERT_PREFIX = "convert_".freeze

  def register
    valid_conversions = %w(string integer float boolean)
    # TODO(sissel): Validate conversion requests if provided.
    @convert.nil? or @convert.each do |field, type|
      if !valid_conversions.include?(type)
        raise LogStash::ConfigurationError, I18n.t(
          "logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter",
          :type => "mutate",
          :error => "Invalid conversion type '#{type}', expected one of '#{valid_conversions.join(',')}'"
        )
      end
    end

    @gsub_parsed = []
    @gsub.nil? or @gsub.each_slice(3) do |field, needle, replacement|
      if [field, needle, replacement].any? {|n| n.nil?}
        raise LogStash::ConfigurationError, I18n.t(
          "logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter",
          :type => "mutate",
          :error => "Invalid gsub configuration #{[field, needle, replacement]}. gsub requires 3 non-nil elements per config entry"
        )
      end

      @gsub_parsed << {
        :field        => field,
        :needle       => (needle.index("%{").nil?? Regexp.new(needle): needle),
        :replacement  => replacement
      }
    end
  end

  def filter(event)
    rename(event) if @rename
    update(event) if @update
    replace(event) if @replace
    convert(event) if @convert
    gsub(event) if @gsub
    uppercase(event) if @uppercase
    lowercase(event) if @lowercase
    strip(event) if @strip
    remove(event) if @remove
    split(event) if @split
    join(event) if @join
    merge(event) if @merge
    move(event) if @move

    filter_matched(event)
  end

  private

  def rename(event)
    @rename.each do |old, new|
      old = event.sprintf(old)
      new = event.sprintf(new)
      next unless event.include?(old)
      event.set(new, event.remove(old))
    end
  end

  def update(event)
    @update.each do |field, newvalue|
      next unless event.include?(field)
      event.set(field, event.sprintf(newvalue))
    end
  end

  def replace(event)
    @replace.each do |field, newvalue|
      event.set(field, event.sprintf(newvalue))
    end
  end

  def convert(event)
    @convert.each do |field, type|
      next unless event.include?(field)
      original = event.get(field)
      # calls convert_{string,integer,float,boolean} depending on type requested.
      converter = method(CONVERT_PREFIX + type)

      case original
      when Hash
        @logger.debug? && @logger.debug("I don't know how to type convert a hash, skipping", :field => field, :value => original)
      when Array
        event.set(field, original.map { |v| converter.call(v) })
      when NilClass
        # ignore
      else
        event.set(field, converter.call(original))
      end
    end
  end

  def convert_string(value)
    # since this is a filter and all inputs should be already UTF-8
    # we wont check valid_encoding? but just force UTF-8 for
    # the Fixnum#to_s case which always result in US-ASCII
    # also not that force_encoding checks current encoding against the
    # target encoding and only change if necessary, so calling
    # valid_encoding? is redundant
    # see https://twitter.com/jordansissel/status/444613207143903232
    value.to_s.force_encoding(Encoding::UTF_8)
  end

  def convert_integer(value)
    value.to_i
  end

  def convert_float(value)
    value.to_f
  end

  def convert_boolean(value)
    return true if value =~ TRUE_REGEX
    return false if value.empty? || value =~ FALSE_REGEX
    @logger.warn("Failed to convert #{value} into boolean.")
    value
  end

  def gsub(event)
    @gsub_parsed.each do |config|
      field = config[:field]
      needle = config[:needle]
      replacement = config[:replacement]

      value = event.get(field)
      case value
      when Array
        result = value.map do |v|
          if v.is_a?(String)
            gsub_dynamic_fields(event, v, needle, replacement)
          else
            @logger.warn("gsub mutation is only applicable for Strings, skipping", :field => field, :value => v)
            v
          end
        end
        event.set(field, result)
      when String
        event.set(field, gsub_dynamic_fields(event, value, needle, replacement))
      else
        @logger.debug? && @logger.debug("gsub mutation is only applicable for Strings, skipping", :field => field, :value => event.get(field))
      end
    end
  end

  def gsub_dynamic_fields(event, original, needle, replacement)
    if needle.is_a?(Regexp)
      original.gsub(needle, event.sprintf(replacement))
    else
      # we need to replace any dynamic fields
      original.gsub(Regexp.new(event.sprintf(needle)), event.sprintf(replacement))
    end
  end

  def uppercase(event)
    @uppercase.each do |field|
      original = event.get(field)
      next if original.nil?
      # in certain cases JRuby returns a proxy wrapper of the event[field] value
      # therefore we can't assume that we are modifying the actual value behind
      # the key so read, modify and overwrite
      result = case original
        when Array
          # can't map upcase! as it replaces an already upcase value with nil
          # ["ABCDEF"].map(&:upcase!) => [nil]
          original.map do |elem|
            (elem.is_a?(String) ? elem.upcase : elem)
          end
        when String
          # nil means no change was made to the String
          original.upcase! || original
        else
          @logger.debug? && @logger.debug("Can't uppercase something that isn't a string", :field => field, :value => original)
          original
        end
      event.set(field, result)
    end
  end

  def lowercase(event)
    #see comments for #uppercase
    @lowercase.each do |field|
      original = event.get(field)
      next if original.nil?
      result = case original
      when Array
        original.map! do |elem|
          (elem.is_a?(String) ? elem.downcase : elem)
        end
      when String
        original.downcase! || original
      else
        @logger.debug? && @logger.debug("Can't lowercase something that isn't a string", :field => field, :value => original)
        original
      end
      event.set(field, result)
    end
  end

  def split(event)
    @split.each do |field, separator|
      value = event.get(field)
      if value.is_a?(String)
        event.set(field, value.split(separator))
      else
        @logger.debug? && @logger.debug("Can't split something that isn't a string", :field => field, :value => event.get(field))
      end
    end
  end

  def join(event)
    @join.each do |field, separator|
      value = event.get(field)
      if value.is_a?(Array)
        event.set(field, value.join(separator))
      end
    end
  end

  def strip(event)
    @strip.each do |field|
      value = event.get(field)
      case value
      when Array
        event.set(field, value.map{|s| s.strip })
      when String
        event.set(field, value.strip)
      end
    end
  end

  def merge(event)
    @merge.each do |dest_field, added_fields|
      # When multiple calls, added_field is an array

      dest_field_value = event.get(dest_field)

      Array(added_fields).each do |added_field|
        added_field_value = event.get(added_field)

        if dest_field_value.is_a?(Hash) ^ added_field_value.is_a?(Hash)
          @logger.error("Not possible to merge an array and a hash: ", :dest_field => dest_field, :added_field => added_field )
          next
        end

        # No need to test the other
        if dest_field_value.is_a?(Hash)
          # do not use event[dest_field].update because the returned object from event[dest_field]
          # can/will be a copy of the actual event data and directly updating it will not update
          # the Event internal data. The updated value must be reassigned in the Event.
          event.set(dest_field, dest_field_value.update(added_field_value))
        else
          # do not use event[dest_field].concat because the returned object from event[dest_field]
          # can/will be a copy of the actual event data and directly updating it will not update
          # the Event internal data. The updated value must be reassigned in the Event.
          event.set(dest_field, Array(dest_field_value).concat(Array(added_field_value)))
        end
      end
    end
  end

  def move(event)
    if @move['field'].nil?
      raise LogStash::ConfigurationError, I18n.t(
          "logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter",
          :type => "mutate",
          :error => "No field to move has been specified"
      )
    end

    field = event.sprintf(@move['field'])
    if event.get(field).nil?
      @logger.warn("No field available in event", :field => field)
      return
    end

    unless event.get(field).is_a?(Hash)
      @logger.warn("Field to move must be a Hash", :field => field, :type => event.get(field).class)
      return
    end

    # delete all target fields first?
    if @move['empty_target'] and convert_boolean(@move['empty_target'])
      # empty the root?
      if @move['target'].nil?
        event.to_hash.each do |k, v|
          event.remove(k) unless k == field
        end
      else
        # empty the target?
        event.set(@move['target'], {})
      end
    else
      # make sure that the target is a Hash and not a string, etc
      unless @move['target'].nil?
        unless event.get(@move['target']).is_a?(Hash)
          event.set(@move['target'], {})
        end
      end
    end

    # move sub-fields to target level
    event.get(field).each do |k, v|
      target_key = k if @move['target'].nil?
      target_key = "#{@move['target']}[#{k}]" unless @move['target'].nil?
      event.set(target_key, v)
    end

    # delete moved sub-field
    event.remove(field)
  end
end
