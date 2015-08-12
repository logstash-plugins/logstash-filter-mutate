# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# The mutate filter allows you to perform general mutations on fields. You
# can rename, remove, replace, and modify fields in your events.
module LogStash module Filters class Mutate < LogStash::Filters::Base
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

  # Remove one or more fields.
  #
  # Example:
  # [source,ruby]
  #     filter {
  #       mutate {
  #         remove => [ "client" ]  # Removes the 'client' field
  #       }
  #     }
  #
  # This option is deprecated, instead use `remove_field` option available in all
  # filters.
  config :remove, :validate => :array, :deprecated => true

  # Replace a field with a new value. The new value can include %{foo} strings
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

  public # --------------------------------------------

  def register
    valid_conversions = %w(string integer float boolean)
    # TODO(sissel): Validate conversion requests if provided.
    @convert.nil? or @convert.each do |field, type|
      if !valid_conversions.include?(type)
        raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter", :type => "mutate",
          :error => "Invalid conversion type '#{type}', expected one of '#{valid_conversions.join(',')}'")
      end
    end # @convert.each

    @gsub_parsed = []
    @gsub.nil? or @gsub.each_slice(3) do |field, needle, replacement|
      if [field, needle, replacement].any? {|n| n.nil?}
        raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter", :type => "mutate",
          :error => "Invalid gsub configuration #{[field, needle, replacement]}. gsub requires 3 non-nil elements per config entry")
      end

      @gsub_parsed << {
        :field        => field,
        :needle       => (needle.index("%{").nil?? Regexp.new(needle): needle),
        :replacement  => replacement
      }
    end
  end # def register

  def filter(event)
    return unless filter?(event)

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

    filter_matched(event)
  end # def filter

  private # --------------------------------------------

  def remove(event)
    # TODO(sissel): use event.sprintf on the field names?
    @remove.each do |field|
      event.remove(field)
    end
  end # def remove

  def rename(event)
    # TODO(sissel): use event.sprintf on the field names?
    @rename.each do |old, new|
      next unless event.include?(old)
      event[new] = event.remove(old)
    end
  end # def rename

  def update(event)
    @update.each do |field, newvalue|
      next unless event.include?(field)
      event[field] = event.sprintf(newvalue)
    end
  end # def update

  def replace(event)
    @replace.each do |field, newvalue|
      event[field] = event.sprintf(newvalue)
    end
  end # def replace

  def convert(event)
    @convert.each do |field, type|
      next unless event.include?(field)
      original = event[field]
      # calls convert_{string,integer,float,boolean} depending on type requested.
      converter = method("convert_" + type)
      case original
      when nil
        next
      when Hash
        @logger.debug("I don't know how to type convert a hash, skipping",
                      :field => field, :value => original)
        next
      when Array
        value = original.map { |v| converter.call(v) }
      else
        value = converter.call(original)
      end
      event[field] = value
    end
  end # def convert

  def convert_string(value)
    # since this is a filter and all inputs should be already UTF-8
    # we wont check valid_encoding? but just force UTF-8 for
    # the Fixnum#to_s case which always result in US-ASCII
    # see https://twitter.com/jordansissel/status/444613207143903232
    return value.to_s.force_encoding(Encoding::UTF_8)
  end # def convert_string

  def convert_integer(value)
    return value.to_i
  end # def convert_integer

  def convert_float(value)
    return value.to_f
  end # def convert_float

  def convert_boolean(value)
    return true if value =~ (/^(true|t|yes|y|1)$/i)
    return false if value.empty? || value =~ (/^(false|f|no|n|0)$/i)
    @logger.warn("Failed to convert #{value} into boolean.")
    return value
  end # def convert_boolean

  def gsub(event)
    @gsub_parsed.each do |config|
      field = config[:field]
      needle = config[:needle]
      replacement = config[:replacement]
      original = event[field]
      if original.is_a?(Array)
        event[field] = original.map do |v|
          if v.is_a?(String)
            gsub_dynamic_fields(event, v, needle, replacement)
          else
            @logger.warn("gsub mutation is only applicable for Strings, " +
                          "skipping", :field => field, :value => v)
            v
          end
        end
      else
        if !original.is_a?(String)
          @logger.debug("gsub mutation is only applicable for Strings, " +
                        "skipping", :field => field, :value => original)
          next
        end
        event[field] = gsub_dynamic_fields(event, original, needle, replacement)
      end
    end # @gsub_parsed.each
  end # def gsub

  def gsub_dynamic_fields(event, original, needle, replacement)
    if needle.is_a? Regexp
      original.gsub(needle, event.sprintf(replacement))
    else
      # we need to replace any dynamic fields
      original.gsub(Regexp.new(event.sprintf(needle)), event.sprintf(replacement))
    end
  end

  def uppercase(event)
    # Issue-33
    # In some cases the event@data is not a real Hash
    # it is a Java HashMap<String, Object> wrapped in a JavaProxy
    # the JavaProxy has #[] method that retrieves the Java Object
    # from the HashMap and wraps it or converts it to a RubyObject
    # If you mutate this object, you are not mutating the original
    # Object in the HashMap. You need to restore this derived object
    # in the HashMap, hence the get, mutate then set pattern.
    @uppercase.each do |field|
      original = event[field]
      event[field] = case original
        when Array
          original.map(&:upcase!)
        when String
          original.upcase!
        else
          @logger.debug("Can't uppercase something that isn't a string",
                        :field => field, :value => original)
          original
        end
    end
  end # def uppercase

  def lowercase(event)
    @lowercase.each do |field|
      original = event[field]
      event[field] = case original
        when Array
          original.map(&:downcase!)
        when String
          original.downcase!
        else
          @logger.debug("Can't lowercase something that isn't a string",
                        :field => field, :value => original)
          original
        end
    end
  end # def lowercase

  def split(event)
    @split.each do |field, separator|
      original = event[field]
      if original.is_a?(String)
        event[field] = original.split(separator)
      else
        @logger.debug("Can't split something that isn't a string",
                      :field => field, :value => original)
      end
    end
  end

  def join(event)
    @join.each do |field, separator|
      original = event[field]
      if original.is_a?(Array)
        event[field] = original.join(separator)
      end
    end
  end

  def strip(event)
    @strip.each do |field|
      original = event[field]
      if original.is_a?(Array)
        event[field] = original.map(&:strip)
      elsif original.is_a?(String)
        event[field] = original.strip
      end
    end
  end

  def merge(event)
    @merge.each do |dest_field, added_fields|
      # When multiple calls, added_field is an array
      target = event[dest_field]
      Array(added_fields).each do |added_field|
        # memoise: no need to invoke Event#[](key) twice
        source = event[added_field]

        if target.is_a?(Hash) ^ source.is_a?(Hash)
          @logger.error("Not possible to merge an array and a hash: ", :dest_field => dest_field, :added_field => added_field )
          next
        end

        if target.is_a?(Hash)
          # No need to test the other
          event[dest_field] = target.update(source)
        else
          event[dest_field] = Array(target).concat(Array(source))
        end
      end
    end
  end

end end end # class LogStash::Filters::Mutate
