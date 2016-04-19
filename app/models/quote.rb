class Quote
  include Mongoid::Document
  include Mongoid::Timestamps
  include MongoidSupport::AssociationProxies

  PERSONAL_RELATIONSHIP_KINDS = [
    :employee,
    :spouse,
    :domestic_partner,
    :child_under_26
    #:child_26_and_over
  ]

  PLAN_OPTION_KINDS = [:single_plan, :single_carrier, :metal_level]
  field :quote_name, type: String, default: "Sample Quote"
  field :plan_year, type: Integer, default: TimeKeeper.date_of_record.year
  field :start_on, type: Date, default: TimeKeeper.date_of_record.beginning_of_year
  field :broker_role_id, type: BSON::ObjectId

  associated_with_one :broker_role, :broker_role_id, "BrokerRole"

  field :plan_option_kind, type: String, default: "single_carrier"

  embeds_many :quote_reference_plans, cascade_callbacks: true
  embeds_many :quote_households


  embeds_many :quote_relationship_benefits, cascade_callbacks: true

  # accepts_nested_attributes_for :quote_households
  accepts_nested_attributes_for :quote_households, reject_if: :all_blank

  def roster_employee_cost(plan_id, reference_plan_id)
    p = Plan.find(plan_id)
    reference_plan = Plan.find(reference_plan_id)
    cost = 0
    self.quote_households.each do |hh|
      pcd = PlanCostDecorator.new(p, hh, self, reference_plan)
      cost = cost + pcd.total_employee_cost.round(2)
    end
    cost.round(2)
  end

  def roster_cost_all_plans
    @plan_costs= {}
    combined_family = flat_roster_for_premiums
    $quote_shop_health_plans.each {|plan|
      @plan_costs[plan.id.to_s] = roster_premium(plan, combined_family)
    }
    @plan_costs
  end

  def roster_premium(plan, combined_family)
    roster_premium = Hash.new{|h,k| h[k]=0.00}
    pcd = PlanCostDecoratorQuote.new(plan, nil, self, plan)
    reference_date = pcd.plan_year_start_on
    pcd.add_premiums(combined_family, reference_date)

  end

  def flat_roster_for_premiums
    p = $quote_shop_health_plans[0]  #any plan
    combined_family = Hash.new{|h,k| h[k] = 0}
    self.quote_households.each do |hh|
      pcd = PlanCostDecoratorQuote.new(p, hh, self, p)
      pcd.add_members(combined_family)
    end
    combined_family
  end

  def roster_employer_contribution(plan_id, reference_plan_id)
    p = Plan.find(plan_id)
    reference_plan = Plan.find(reference_plan_id)
    cost = 0
    self.quote_households.each do |hh|
      pcd = PlanCostDecorator.new(p, hh, self, reference_plan)
      cost = cost + pcd.total_employer_contribution.round(2)
    end
    cost.round(2)
  end

  def build_relationship_benefits
    self.quote_relationship_benefits = PERSONAL_RELATIONSHIP_KINDS.map do |relationship|
       self.quote_relationship_benefits.build(relationship: relationship, offered: true)
    end
  end

  def cost_by_offerings(plan)
    plan_costs_by_offerings = Hash.new
    PLAN_OPTION_KINDS.map { |offering| plan_costs_by_offerings[offering] = bounding_cost_plans(plan, offering.to_s) }
    plan_costs_by_offerings.merge({"reference_plan_cost" => roster_employer_contribution(plan.id, plan.id)})
  end

  def bounding_cost_plans (reference_plan, plan_option_kind)
      if plan_option_kind == "single_plan"
        plans = [reference_plan]
      else
        if plan_option_kind == "single_carrier"
          plans = Plan.shop_health_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile)
        else
          plans = Plan.shop_health_by_active_year(reference_plan.active_year).by_health_metal_levels([reference_plan.metal_level])
        end
      end

      if plans.size > 0
        plans_by_cost = plans.sort_by { |plan| plan.premium_tables.first.cost }

        {"lowest_cost_plan_cost" => roster_employer_contribution(plans_by_cost.first.id, reference_plan.id), "highest_cost_plan_cost" => roster_employer_contribution(plans_by_cost.last.id, reference_plan.id)}
      else
        {}
      end
  end


  def calc_by_plan(plan_id)

    if quote_households.exists?

      quote_households.each do |hh|
        puts "Found household of size " + hh.quote_members.count.to_s
      end
    end
  end

  def relationship_benefit_for(relationship)
    quote_relationship_benefits.where(relationship: relationship).first
  end


  def calc

    rp1 = self.quote_reference_plans.build(reference_plan_id:  "56e6c4e53ec0ba9613008f6d")
    rp1.set_bounding_cost_plans
    rp1.save
    #reference_plan=("56e6c4e53ec0ba9613008f6d")

    p = Plan.find(self.quote_reference_plans[0].reference_plan_id)

    puts "Calculating details for " + p.name

      self.quote_households.each do |hh|
        puts "   " + hh.quote_members.first.first_name
        pcd = PlanCostDecorator.new(p, hh, self, p)
        puts "Employee Cost " + pcd.total_employee_cost.to_s
        puts "Employer Contribution " + pcd.total_employer_contribution.to_s

        rp1.quote_results << pcd.get_family_details_hash
      end


      self.save
  end

  def gen_data

    self.quote_name = "My Sample Quote"
    self.plan_option_kind = "single_carrier"
    self.plan_year = 2016
    self.start_on = Date.new(2016,5,2)

    build_relationship_benefits
    self.relationship_benefit_for("employee").premium_pct=(70)
    self.relationship_benefit_for("child_under_26").premium_pct=(100)

    qh = self.quote_households.build

    qm = qh.quote_members.build

    qm.first_name = "Tony"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1980,7,26)
    qm.employee_relationship = "employee"

    qm = qh.quote_members.build

    qm.first_name = "Gabriel"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Steve"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Lucas"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Enzo"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Leonardo"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1991,1,10)
    qm.employee_relationship = "child_under_26"

    self.save

    qh = self.quote_households.build
    qm = qh.quote_members.build

    qm.first_name = "Andressa"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1988,9,27)
    qm.employee_relationship = "employee"

    qm = qh.quote_members.build

    qm.first_name = "Alice"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2014,1,13)
    qm.employee_relationship = "child_under_26"
    self.save

    self.calc

  end

end