# active_aggregate

 - active_aggregate is a little helper support to queries by mongoDB aggregate more easily.
 - A toolkit for building queries like ActiveRelation. Rich support for more flexible merge conditions, states

## Getting started

```ruby
gem install active_aggregate
```

## Requirements
 - mongoid >= 5.0.1

## Usage

```ruby
# models/user.rb
class User
  include Mongoid::Document

  belongs_to :school
  belongs_to :branch

  scope :active, -> { where(status: :active) }
  scope :by_status, ->(status) { where(status: status) }
end

class Query
  include ActiveAggregate::Concern
end

class UserQuery < Query
  define_for User

  # you can use `criteria.active` instead of `User.active`
  scope :load_active_user_names, criteria: User.active,
        project: {
          id: '$_id',
          name: {
            '$concat': [
              '$first_name',
              ' ',
              '$last_name',
            ]
          }
        }

  scope :not_deleted, criteria: User.where(deleted_at: nil)
  scope :load_user_ids,
        ->(status:, school_id_branch_ids:) do
          where(status: status).pipeline(
            '$match': {
              'school_id_branch_id': {
                '$in': school_id_branch_ids,
              }
            }
          )

          # it avaiable to use like
          # query_criteria(User.by_status(status)).pipeline([
          #   '$match': {
          #     'school_id_branch_id': {
          #       '$in': school_id_branch_ids,
          #     }
          #   }
          # ])

        end,
        project: {
          id: '$_id',
          school_id_branch_id: {
            '$concatArrays': [
              ['$school_id'],
              ['$branch_id'],
            ]
          }
        }
end

# another way
# class Query
#   include ActiveAggregate::Concern

#   # On children class it will remove [suffix] at end of class name to get model name then you can skip call define_for each all of Query class
#   # [suffix] have default value is Query
#   with_suffix
#   # with_suffix suffix: :Query
# end

# class UserQuery < Query
# end


UserQuery.not_deleted.load_user_ids.where(:created_at.lt => Time.current)
```

- `scope` support define for:
  - criteria: as `Mongoid::Criteria` it will place at first of pipeline if given, by default it is default scope
  - group: as object, can be merge throw all queries.
  - project: as object, will be replace throw merge ActiveAggregate::Relation
  - sort, limit: as object, will be replace throw merge ActiveAggregate::Relation.
  - pipeline: as Array will place end of pre-pipeline if given, merge with previous pipeline by concat 2 array
`scope` will generate pipeline to use with aggregate with states order by:
 - State 1 is `$match` use`criteria` selector if selector present
 - state 2 is `$group` if `group` given
 - state 3 is `$project` if `project` given
 - state 3 is `$limit` if `limit` given
 - pipeline will be place from here
