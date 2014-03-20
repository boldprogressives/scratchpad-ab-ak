class ActionKitEventNotification < EventNotification
 
  def page_parms
    out = {}
    out[:name] = "ab_#{contribution.list ? contribution.list.name : 'no_page_name'}"
    out[:title] = "[AB] #{lineitem.contribution.list.title}"
    out[:lists] = target_config.lists.gsub(/ /, '') if target_config.lists.present?
    out[:tags] = target_config.tag_ids if target_config.tag_ids
    out
  end
 
  def donation_parms
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
    out[:action_employer_address1] = contribution.empaddr1
    out[:action_employer_address2] = contribution.empaddr2
    out[:action_employer_city] = contribution.empcity
    out[:action_employer_state] = contribution.empstate
    out[:action_employer_zip] = contribution.empzip
    out[:action_employer_country] = contribution.empcountry
    
    # yes, we are still going to do this the exact same way
    out[:action_recurrence_number] = lineitem.sequence.to_s
    out[:action_recurrence_total_months] = contribution.recurringtimes.to_s if contribution.recurringtimes > 1
    
    out[:action_recipient_name] = lineitem.entity.committeename
    out[:action_recipient_id] = lineitem.entity_id.to_s
    out[:action_payment_id] = lineitem.payment_id.to_s
    out[:action_actblue_contribution_id] = contribution.order_number
    out[:created_at] = lineitem.payment.effective_on.utc.strftime("%-m/%-d/%y %H:%M") if lineitem.payment && lineitem.payment.effective_on
    out[:opt_in] = target_config.opt_in.to_s unless target_config.opt_in.nil?
    record_id = "actblue#{lineitem.id}"
    if target_config.entity_ids && target_config.entity_ids.include?(lineitem.entity_id)
      #if this contribution is to the owner of this notification (i.e. to the PCCC on a PCCC page)
      out[:donation_import_id] = record_id
      out[:donation_date] = lineitem.created_at.utc.strftime("%-m/%-d/%y %H:%M")
      out[:donation_amount] = lineitem.amount.to_dollars(:commify => false)
    else
      out[:action_actblueid] = record_id
      out[:action_date] = lineitem.created_at.utc.strftime("%-m/%-d/%y %H:%M")
      out[:action_amount] = lineitem.amount.to_dollars(:commify => false)
    end
    out.delete_if{|k,v| v.nil? }
    out
  end
 
  def execute
    begin
      conn = target_config.actionkit_connection
 
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