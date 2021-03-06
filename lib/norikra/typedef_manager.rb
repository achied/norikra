require 'digest'

require 'norikra/typedef'

module Norikra
  class TypedefManager
    attr_reader :typedefs

    def initialize(opts={})
      @typedefs = {} # {target => Typedef}
      @mutex = Mutex.new
    end

    def field_list(target)
      @typedefs[target].fields.values.sort{|a,b| a.name <=> b.name}.map(&:to_hash)
    end

    def add_target(target, fields)
      # fields nil => lazy
      # fields {'fieldname' => 'type'}
      @mutex.synchronize do
        raise RuntimeError, "target #{target} already exists" if @typedefs[target]
        @typedefs[target] = Typedef.new(fields)
      end
    end

    def lazy?(target)
      @typedefs[target].lazy?
    end

    def activate(target, fieldset)
      @typedefs[target].activate(fieldset)
    end

    def reserve(target, field, type)
      @typedefs[target].reserve(field, type)
    end

    def fields_defined?(target, field_name_list)
      @typedefs[target].field_defined?(field_name_list)
    end

    def bind_fieldset(target, level, fieldset)
      fieldset.bind(target, level)
      @typedefs[target].push(level, fieldset)
    end

    def generate_base_fieldset(target, event)
      guessed = Norikra::FieldSet.simple_guess(event, false) # all fields are non-optional
      guessed.update(@typedefs[target].fields, false)
      guessed
    end

    def generate_query_fieldset(target, field_name_list)
      # all fields of field_name_list should exists in definitions of typedef fields
      # for this premise, call 'bind_fieldset' for data fieldset before this method.
      required_fields = {}
      @mutex.synchronize do
        @typedefs[target].fields.each do |fieldname, field|
          if field_name_list.include?(fieldname) || !(field.optional?)
            required_fields[fieldname] = {:type => field.type, :optional => field.optional}
          end
        end
      end
      Norikra::FieldSet.new(required_fields)
    end

    def base_fieldset(target)
      @typedefs[target].baseset
    end

    def subsets(target, fieldset) # for data fieldset
      sets = []
      @mutex.synchronize do
        @typedefs[target].queryfieldsets.each do |set|
          sets.push(set) if set.subset?(fieldset)
        end
        sets.push(@typedefs[target].baseset)
      end
      sets
    end

    def refer(target, event)
      @typedefs[target].refer(event)
    end

    def format(target, event)
      @typedefs[target].format(event)
    end
  end
end
