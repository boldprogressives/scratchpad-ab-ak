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

    lookups = order_lookups(out.page)   # @@TODO: function checks AK page and builds lookup
    contribution.lineitems.each do line # table/function for ab-entity-to-ak-page-order
      out["donation_#{lookups(line)}"] = line.amount.to_dollars(:commify => false)
      # if there were products we would handle that here too I think
     
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