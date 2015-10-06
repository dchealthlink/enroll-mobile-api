module PdfTemplates
  class Individual
    include Virtus.model

    attribute :full_name, String

    attribute :ssn_verified, Boolean, :default => false
    attribute :citizenship_verified, Boolean, :default => false
    attribute :residency_verified, Boolean, :default => false
    attribute :indian_conflict, Boolean, :default => false
    
    # attribute :ineligible_members, Array[String]
    # attribute :ineligible_members_due_to_residency, Array[String]
    # attribute :ineligible_members_due_to_incarceration, Array[String]
    # attribute :ineligible_members_due_to_immigration, Array[String]
    # attribute :active_members, Array[String]
    # attribute :inconsistent_members, Array[String]
    # attribute :eligible_immigration_status_members, Array[String]
    # attribute :members_with_more_plans, Array[String]
    # attribute :indian_tribe_members, Array[String]
    # attribute :unverfied_resident_members, Array[String]
    # attribute :unverfied_citizenship_members, Array[String]
    # attribute :unverfied_ssn_members, Array[String]


    def verified
      (ssn_verified && citizenship_verified && residency_verified && !indian_conflict)
    end
  end
end
