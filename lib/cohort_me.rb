require "cohort_me/version"

module CohortMe
  def self.analyze(options={})
    start_from_interval = options[:start_from_interval] || 12
    interval_name = options[:period] || "weeks"
    activation_class = options[:activation_class]
    activation_table_name = ActiveModel::Naming.plural(activation_class)
    activation_user_id = options[:activation_user_id] || "user_id"
    activation_conditions = options[:activation_conditions]
    activation_field = options[:activation_field] || "created_at"

    activity_class = options[:activity_class] || activation_class
    activity_table_name = ActiveModel::Naming.plural(activity_class)
    activity_user_id = options[:activity_user_id] || "user_id"
    activity_field = options[:activity_field] || activation_field

    period_values = %w[weeks days months]

    raise "Period '#{interval_name}' not supported. Supported values are #{period_values.join(' or ')}" unless period_values.include? interval_name

    start_from = nil
    time_conversion = nil
    cohort_label = nil

    if interval_name == "weeks"
      start_from = start_from_interval.weeks.ago
      time_conversion = 604800
    elsif interval_name == "days"
      start_from = start_from_interval.days.ago
      time_conversion = 86400
    elsif interval_name == "months"
      start_from = start_from_interval.months.ago
      time_conversion = 1.month.seconds
    end

    cohort_query = activation_class.select("#{activation_table_name}.#{activation_user_id}, MIN(#{activation_table_name}.#{activation_field}) as cohort_date").group("#{activation_user_id}").where("#{activation_field} > ?", start_from)

    if activation_conditions
      cohort_query = cohort_query.where(activation_conditions)
    end

    if %(mysql mysql2).include?(ActiveRecord::Base.connection.instance_values["config"][:adapter])

      select_sql = "#{activity_table_name}.#{activity_user_id}, #{activity_table_name}.#{activity_field}, cohort_date, FLOOR(TIMEDIFF(#{activity_table_name}.#{activity_field}, cohort_date)/#{time_conversion}) as periods_out"
    elsif ActiveRecord::Base.connection.instance_values["config"][:adapter] == "postgresql"
      select_sql = "#{activity_table_name}.#{activity_user_id}, #{activity_table_name}.#{activity_field}, cohort_date, FLOOR(extract(epoch from (#{activity_table_name}.#{activity_field} - cohort_date))/#{time_conversion}) as periods_out"
    else
      raise "database not supported"
    end

    data = activity_class.where("#{activity_field} > ?", start_from).select(select_sql).joins("JOIN (" + cohort_query.to_sql + ") AS cohorts ON #{activity_table_name}.#{activity_user_id} = cohorts.#{activation_user_id}")

    unique_data = data.all.uniq{|d| [d.send(activity_user_id), d.cohort_date, d.periods_out] }

    analysis = unique_data.group_by{|d| convert_to_cohort_date(Time.parse(d.cohort_date.to_s), interval_name)}
    cohort_hash = Hash[analysis.sort_by { |cohort, data| cohort }]

    table = {}
    cohort_hash.each do |r|
      periods = []
      table[r[0]] = {}

      cohort_hash.size.times{|i| periods << r[1].count{|d| d.periods_out.to_i == i} if r[1]}

      table[r[0]][:count] = periods
      table[r[0]][:data] = r[1]
    end

    table
  end

  def self.convert_to_cohort_date(datetime, interval)
    case interval
    when "weeks";  datetime.at_beginning_of_week.to_date
    when "days";   Date.parse(datetime.strftime("%Y-%m-%d"))
    when "months"; Date.parse(datetime.strftime("%Y-%m-01"))
    end
  end
end
