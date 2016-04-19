class DocumentsController < ApplicationController
  before_action :set_document, only: [:destroy, :update]
  before_action :set_person, only: [:enrollment_docs_state, :update_individual, :fed_hub_request, :enrollment_verification]
  respond_to :html, :js

  def download
    bucket = params[:bucket]
    key = params[:key]
    uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket}##{key}"
    send_data Aws::S3Storage.find(uri), get_options(params)
  end

  def update_individual
    @person.consumer_role.import! verification_attr
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end

  def enrollment_verification
    @person.primary_family.active_household.hbx_enrollments.verification_needed.first.evaluate_individual_market_eligiblity
    respond_to do |format|
      format.html {
        flash[:success] = "Enrollment group was completely verified."
        redirect_to :back
      }
      format.js
    end
  end

  def fed_hub_request
    @person.consumer_role.start_individual_market_eligibility!(TimeKeeper.date_of_record)
    respond_to do |format|
      format.html {
        flash[:success] = "Request was sent to FedHub."
        redirect_to :back
      }
      format.js
    end
  end

  def enrollment_docs_state
    @person.primary_family.active_household.hbx_enrollments.verification_needed.first.update_attributes(:review_status => params[:docs_status])
    flash[:success] = "Your documents were sent for verification."
    redirect_to :back
  end

  def show_docs
    if current_user.has_hbx_staff_role?
      session[:person_id] = params[:person_id]
      set_current_person
      @person.primary_family.active_household.hbx_enrollments.verification_needed.first.update_attributes(:review_status => params[:status])
    end
    redirect_to verification_insured_families_path
  end

  def extend_due_date
    family = Family.find(params[:family_id])
      if family.try(:active_household).try(:hbx_enrollments).try(:verification_needed).try(:first).try(:special_verification_period)
        family.active_household.hbx_enrollments.verification_needed.first.special_verification_period += 30.days
        if family.save!
          flash[:success] = "Special verification period was extended for 30 days."
        end
      else
        if family.try(:active_household).try(:hbx_enrollments).try(:verification_needed).try(:first)
          family.active_household.hbx_enrollments.verification_needed.first.update_attributes(:special_verification_period => TimeKeeper.date_of_record + 30.days)
          flash[:success] = "You set special verification period for this Enrollment. Verification due date now is #{family.active_household.hbx_enrollments.verification_needed.first.special_verification_period}"
        end
      end
    redirect_to :back
  end

  def destroy
    @document.delete
    respond_to do |format|
      format.html { redirect_to verification_insured_families_path }
      format.js
    end

  end

  def update
    if params[:comment]
      @document.update_attributes(:status => params[:status],
                                  :comment => params[:person][:vlp_document][:comment])
    else
      @document.update_attributes(:status => params[:status])
    end
    respond_to do |format|
      format.html {redirect_to verification_insured_families_path, notice: "Document Status Updated"}
      format.js
    end
  end

  private
  def get_options(params)
    options = {}
    options[:content_type] = params[:content_type] if params[:content_type]
    options[:filename] = params[:filename] if params[:filename]
    options[:disposition] = params[:disposition] if params[:disposition]
    options
  end

  def set_document
    set_person
    @document = @person.consumer_role.vlp_documents.find(params[:id])
  end

  def set_person
    @person = Person.find(params[:person_id])
  end

  def verification_attr
    OpenStruct.new({
       :vlp_verified_at => Time.now,
       :vlp_authority => "hbx",
       :citizen_status => params[:citizenship]
                   })
  end
end
