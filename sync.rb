class ActionKitEventNotification < EventNotification
 
  def candidate_parms
    out = {}
    out[:name] = lineitem.entity_name # make sure this named correctly, the candidate/committee's actual name
    out[:description] = lineitem.entity_description # if applicable 
    out[:portrain_url] = target_config.lists.gsub(/ /, '') if target_config.lists.present?
    # out[:hidden] = don't really set this, but it's available
    # out[:stub_id] = open question how we set this via API
    out
  end
  
  def page_parms
    out = {}
    out[:name] = "ab_#{contribution.list ? contribution.list.name : 'no_page_name'}"
    out[:title] = "[AB] #{lineitem.contribution.list.title}"
    out[:lists] = target_config.lists.gsub(/ /, '') if target_config.lists.present?
    out[:tags] = target_config.tag_ids if target_config.tag_ids
    out
  end
 
  # donation_parms
  #
  # change something, so we're only running 'donation parms' once per contribution
  # instead of once per lineitem. this function now assume contribution.lineitems
  # is an array or list of all lineitems, and no longer access lineitem directly
  #
  
  def donation_parms
    # this section will be run once per donation, not N-times for N lineitems.
    out = {}
    out[:page] = "ab_#{contribution.list ? contribution.list.name : 'no_page_name'}"
    out[:action_recipient] = lineitem.entity.displayname
    out[:source]=contribution.refcode
    out[:mailing_id]=contribution.refcode2
    out[:first_name] = contribution.firstname
    out[:last_name] = contribution.lastname
    out[:address1] = contribution.addr1
    out[:address2] = contribution.addr2
    out[:city] = contribution.city
    out[:state] = contribution.state
    out[:zip] = contribution.zip
    out[:country] = contribution.country
    out[:user_occupation] = contribution.occupation
    out[:user_employer] = contribution.employer
    out[:email] = contribution.email
    out[:phone] = contribution.phone
    out[:donation_date] = lineitem.created_at.utc.strftime("%-m/%-d/%y %H:%M")
    out[:created_at] = lineitem.payment.effective_on.utc.strftime("%-m/%-d/%y %H:%M") if lineitem.payment && lineitem.payment.effective_on
    out[:opt_in] = target_config.opt_in.to_s unless target_config.opt_in.nil?

    # @@TODO: find out what these 3 fields actually mean
    # 1. the first of the 3, I think the highest-level identifier
    out[:action_actblue_contribution_id] = contribution.order_number

    #2. the second of the 3, I think the second most specific
    out[:donation_import_id] = "actblue#{lineitem.id}"
    #3. the most specific. 1 per swipe-part per recurrence ??
    out[:action_payment_id] = lineitem.payment_id.to_s

    # yes, we are still going to do this the exact same way
    out[:action_recurrence_number] = lineitem.sequence.to_s
    out[:action_recurrence_total_months] = contribution.recurringtimes.to_s if contribution.recurringtimes > 1

    # here is the only part we actually have to loop over per-line-item. this way of doing the loop
    # doesn't create multiple actions per lineitem, it simply uses columns like candidate_102 to 
    # target contributions to the candidate whose ID in AK is 102. core_order_detail records should
    # be created correctly using the existing import file method.
    
    contribution.lineitems.each do lineitem 
      out["candidate_#{lineitem.akid}"] = lineitem.amount.to_dollars(:commify => false)
    end
     
    out.delete_if{|k,v| v.nil? }
    out
  end
 
  def execute
    begin
      conn = target_config.actionkit_connection
 
      # function save_or_create_candidate: an un-written function to ensure all the 
      # candidate's (recipient committees) are represented in the ActionKit database,
      # and that our `lineitem` object is aware of each recipient's `core_candidate.id`
      #  value in order to construct the donation import correctly.
      candidate_rec = conn.save_or_create_candidate(candidate_parms)
      # after running this function, we assume the existence of a `lineitem.akid` which
      # represents the corresponding record in the AK database.
      
      page_rec = conn.save_or_create_page(page_parms)

      conn.record_donation(page_rec["id"], donation_parms)
      
      self.status = "success"
      self.response_string = conn.last_response_body
    rescue Exception => e
      logger.debug "ActionKit rescued error #{e}"
      logger.debug "#{e.backtrace.join("\n")}"
      logger.debug "ActionKit last response: #{conn.last_response_body}" if conn && conn.last_response_body
      self.response_string = (conn && conn.last_response_body) || e.inspect
      self.status = "retry"
    end
    self.save!
  end
end