module ActiveAggregate::Concern
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :model, :criteria

    delegate :query, :query_criteria, :group, :project, :pipeline, :group_by, :to_a,
             :where, :in, :any_off, :all_of,
             to: :all

    def define_for(model)
      @model = model
      @criteria = model.all
    end

    def scope(name, *options)
      raise TypeError, 'set defined scope for model first' unless model
      scope_name = name.to_sym
      scopes[scope_name] = ActiveAggregate::Relation.new(self, *options)
      singleton_class.send(:define_method, scope_name) do |*args|
        return scopes[scope_name].generate(*args)
      end
    end

    def all
      raise TypeError, 'set defined scope for model first' unless model
      ActiveAggregate::Relation.new(self).generate
    end

    def scope_names
      scopes.keys
    end

    def scope?(scope_name)
      scopes.key?(scope_name.to_sym)
    end

    def respond_to_missing?(method_name, include_private = false)
      scope?(method_name) || super
    end

    def method_missing(scope_name, *args, &block)
      name = scope_name.to_sym
      if scope?(name)
        merge(public_send(name, *args, &block))
      else
        super
      end
    end

    def scopes
      @scopes ||= {}
    end
  end
end
