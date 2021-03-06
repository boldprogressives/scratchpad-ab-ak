class ActionKitEventNotification < EventNotification
 
  def candidate_parms
    out = {}
    out[:name] = lineitem.entity_name # make sure this named correctly, the candidate/committee's actual name
    out[:description] = lineitem.entity_description # if applicable 
    out[:portrain_url] = lineitem.entity_photo # if applicable
    # out[:hidden] = don't really set this, but it's available
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
    
    if lineitem.sequence.to_s > 1 

      # unwritten function
      action_id = lookup_actionid_by_importid("actblue#{contribution.order_number}")

      if action_id is not null

        # unwritten function
        update_action({'action_recurrence_number': lineitem.sequence.to_s }) 

        return # DO NOT add a line to the import spreadsheet
      end 

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
    out[:opt_in] = target_config.opt_in.to_s unless target_config.opt_in.nil?
    
    # make sure to use properties of the "donation" object instead
    # should make sure we're using the datestamps of the original action (in case this is a second
    # recurrence making up for an initial error on the first pass (edge case)).
    
    # use donation.created_at or donation.lineitems[0].created_at for both of these? what's the difference?
    out[:donation_date] = lineitem.created_at.utc.strftime("%-m/%-d/%y %H:%M")
    out[:created_at] = lineitem.payment.effective_on.utc.strftime("%-m/%-d/%y %H:%M") if lineitem.payment && lineitem.payment.effective_on

    # This will be the one canonical import ID, one per order, regardless of the number of
    # candidates, recurrences, lineitems, or whathaveyous involved. 
    out[:donation_import_id] = "ab_#{contribution.order_number}"
    
    # okay, we are not really changing the way this works. just this function only runs the first recurrence.
    out[:action_recurrence_total_months] = contribution.recurringtimes.to_s if contribution.recurringtimes > 1
    out[:action_recurrence_number] = lineitem.sequence.to_s # this should only ever be '1' unless there was an error

    # here is the only part we actually have to loop over per-line-item.     
    contribution.lineitems.each do lineitem 
      out["candidate_#{lineitem.akid}"] = lineitem.amount.to_dollars(:commify => false)
      out[:action_lineitem_ids] += lineitem.id + ','
      out[:action_payment_ids] += lineitem.to_s + ','
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