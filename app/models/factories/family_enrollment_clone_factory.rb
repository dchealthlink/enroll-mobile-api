module Factories
  class FamilyEnrollmentCloneFactory
    include Mongoid::Document
    attr_accessor :family, :census_employee, :enrollment

    def clone_for_cobra
      raise ArgumentError if !defined?(@family) || !defined?(@census_employee)

      clone_enrollment = clone_builder(@enrollment)
      clone_enrollment = clone_cobra_enrollment(@enrollment, clone_enrollment)
      clone_enrollment.decorated_hbx_enrollment
      save_clone_enrollment(clone_enrollment, @enrollment)
      #terminate_history_enrollment(@enrollment)
    end

    def clone_builder(active_enrollment)
      clone_enrollment  = @family.active_household.new_hbx_enrollment_from(
        employee_role: @census_employee.employee_role,
        benefit_group: active_enrollment.benefit_group,
        coverage_household: @family.active_household.immediate_family_coverage_household,
        benefit_group_assignment: active_enrollment.benefit_group_assignment)
      clone_enrollment
    end

    def save_clone_enrollment(clone_enrollment, active_enrollment)
      if clone_enrollment.save
        clone_enrollment
      else
        message = "Enrollment: #{active_enrollment.id}, \n" \
        "Unable to save clone enrollment: #{clone_enrollment.inspect}, \n" \
          "Error(s): \n #{clone_enrollment.errors.map{|k,v| "#{k} = #{v}"}.join(" & \n")} \n"

        Rails.logger.error { message }
        raise FamilyEnrollmentCloneFactory, message
      end
    end

    def terminate_history_enrollment(enrollment)
      @enrollment.benefit_group_assignment.update(hbx_enrollment_id: @enrollment.id) if @enrollment.benefit_group_assignment.present?
      term_date = TimeKeeper.date_of_record
      enrollment.terminate_benefit(term_date)
      enrollment.propogate_terminate(term_date)
    end

    def need_renew_plan_for_cobra?
      @census_employee.cobra_linked? &&
      @census_employee.cobra_begin_date.present? &&
      @census_employee.active_benefit_group_assignment.start_on.year + 1 == @census_employee.cobra_begin_date.year
    end

    def effective_on_for_cobra
      @census_employee.coverage_terminated_on.end_of_month + 1.days 
    end

    def clone_cobra_enrollment(active_enrollment, clone_enrollment)
      clone_enrollment.benefit_group_assignment_id = active_enrollment.benefit_group_assignment_id
      clone_enrollment.benefit_group_id = active_enrollment.benefit_group_id

      clone_enrollment.employee_role_id = active_enrollment.employee_role_id

      if need_renew_plan_for_cobra?
        clone_enrollment.plan_id = active_enrollment.plan.renewal_plan_id
        raise FamilyEnrollmentCloneFactoryError if clone_enrollment.plan_id.blank?
      else
        clone_enrollment.plan_id = active_enrollment.plan_id
      end
      clone_enrollment.kind = 'employer_sponsored_cobra'
      clone_enrollment.effective_on = effective_on_for_cobra
      clone_enrollment.select_coverage
      clone_enrollment.generate_hbx_signature

      clone_enrollment.hbx_enrollment_members = clone_enrollment_members(active_enrollment)
      clone_enrollment
    end
      
    def clone_enrollment_members(active_enrollment)
      hbx_enrollment_members = active_enrollment.hbx_enrollment_members
      hbx_enrollment_members.inject([]) do |members, hbx_enrollment_member|
        members << HbxEnrollmentMember.new({
          applicant_id: hbx_enrollment_member.applicant_id,
          eligibility_date: effective_on_for_cobra,
          coverage_start_on: effective_on_for_cobra,
          is_subscriber: hbx_enrollment_member.is_subscriber
        })
      end
    end
  end
  
  class FamilyEnrollmentCloneFactoryError < StandardError; end
end
