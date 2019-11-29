class ActiveAggregate::Relation
  include ActiveSupport::Concern

  attr_reader :scope_class, :body

  def initialize(scope_class, body = nil, options = {})
    @scope_class = scope_class
    if body.respond_to?(:call)
      init_default_value(options)
      @body = body
    else
      init_default_value(body.nil? ? options : body)
    end
  end

  delegate :scope?, :scope_names, :model, to: :scope_class
  delegate :selector, to: :criteria
  delegate :to_a, :count, :first, to: :aggregate
  delegate :select, :find, :last, :group_by, :each_with_object, :each,
           :map, :reduce, :reject,
           to: :to_a

  def query(options)
    case options
    when Hash
      merge(self.class.new(scope_class, options))
    when self.class
      merge(options)
    else
      self
    end
  end

  def query_criteria(options)
    query(criteria: options)
  end

  def group(options)
    query(group: options)
  end

  def pipeline(options)
    query(pipeline: options)
  end

  def project(options)
    query(project: options)
  end

  def sort(options)
    @sort = options
    self
  end

  def limit(options)
    @limit = options
    self
  end

  def expose
    {
      pipeline: @pipeline,
      criteria: @criteria,
      group: @group,
      project: @project,
      sort: @sort,
      limit: @limit
    }
  end

  def generate_project
    return @project if @project.present?
    selector.keys.each_with_object({}) { |con, hashes| hashes[con] = "$#{con}" }
  end

  def selector
    @criteria ? @criteria.selector : {}
  end

  def generate_execute_pipeline(select_all: false, aggregate: {})
    merge(aggregate) if aggregate.present?
    [].tap do |execute_pipeline|
      execute_pipeline << { '$match': selector } if selector.present?
      execute_pipeline << { '$group': @group } if @group.present?
      execute_pipeline << { '$sort': @sort } if @sort.present?
      execute_pipeline << { '$project': project_selector } if select_all || @project.present?
      execute_pipeline << { '$limit': @limit } if @limit.present?
      execute_pipeline.push(*@pipeline)
    end
  end

  def generate(*args)
    return self if body.nil?
    result = scope_class.instance_exec(*args, &body)
    case result
    when Hash
      init_default_value(merge_exposed(result))
      self
    when self.class
      merge(result)
    else
      self
    end
  end

  def aggregate(options = {}, *args)
    model.collection.aggregate(generate_execute_pipeline(options), *args)
  end

  def add_pipeline(*stages)
    @pipeline.push(*stages.flatten)
  end

  def override(*stages)
    @pipeline = stages.flatten
  end

  def respond_to_missing?(method_name, include_private = false)
    scope?(scope_name) || super
  end

  def method_missing(scope_name, *args, &block)
    name = scope_name.to_sym
    if scope?(scope_name)
      merge(scope_class.public_send(name, *args, &block))
    else
      super
    end
  end

  def where(*args)
    query_criteria(model.where(*args))
  end

  def in(*args)
    query_criteria(model.in(*args))
  end

  alias_method :where_in, :in

  def any_of(*args)
    query_criteria(model.any_of(*args))
  end

  def all_of(*args)
    query_criteria(model.all_of(*args))
  end

  def merge(relation)
    if !relation.is_a?(ActiveAggregate::Relation) || relation.scope_class != scope_class
      raise TypeError, "#relation much be an ActiveAggregate::Relation of #{scope_class}"
    end
    self.class.new(scope_class, merge_exposed(relation.expose))
  end

  def merge_exposed(exposed)
    {
      pipeline: @pipeline + (exposed[:pipeline] || []),
      criteria: [@criteria, format_criteria(exposed[:criteria])].compact.reduce(&:merge),
      group: [@group, exposed[:group]].compact.reduce(&:deep_merge),
      project: [@project, exposed[:project]].compact.reduce(&:deep_merge),
      sort: exposed[:sort] || nil,
      limit: exposed[:limit] || nil
    }
  end

  private

  def init_default_value(criteria: model.all, pipeline: [], group: nil, project: nil, sort: nil, limit: nil)
    @criteria = format_criteria(criteria)
    @pipeline = pipeline.present? ? pipeline : []
    @group = group.present? ? group : {}
    @project = project.present? ? project : {}
    @sort = sort
    @limit = limit
  end

  def format_criteria(criteria)
    case criteria
    when Mongoid::Criteria
      criteria
    when self.class
      format_criteria(criteria.expose[:criteria])
    end
  end
end
