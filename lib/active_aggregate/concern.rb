module ActiveAggregate::Concern
  extend ActiveSupport::Concern

  class_methods do
    delegate :query, :query_criteria, :group, :project, :pipeline, :group_by, :to_a,
             :where, :in, :where_in, :any_off, :all_of,
             to: :all

    def scope(name, *options)
      required_model!
      scope_name = name.to_sym
      singleton_class.send(:define_method, scope_name) do |*args|
        scopes[scope_name] = ActiveAggregate::Relation.new(self, *options)
        return scopes[scope_name].generate(*args)
      end
    end

    def all
      required_model!
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

    def model
      @model ||= load_model
    end

    def criteria
      @criteria ||= load_model.all
    end

    private

    def define_for(model)
      @criteria = model.all
      @model = model
    end

    def with_suffix(suffix: :Query)
      singleton_class.send(:define_method, :suffix) do
        suffix
      end
    end

    def load_model
      @model || define_for_model_by_remove_suffix
    end

    def define_for_model_by_remove_suffix
      return if !defined?(suffix) || suffix.nil?
      model_name = name[0..(name.length - suffix.length - 1)]
      define_for(model_name.constantize)
    end

    def required_model!
      raise TypeError, 'set defined scope for model first' unless model
    end
  end
end
