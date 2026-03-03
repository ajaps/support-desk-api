# frozen_string_literal: true

# This file is idempotent: re-running it in development clears and recreates all data.
# Run with: bin/rails db:seed

puts "Seeding database..."

# ──────────────────────────────────────────────────────────────
# Clear existing data (development only)
# ──────────────────────────────────────────────────────────────
if Rails.env.development?
  puts "  Clearing existing records..."
  Export.destroy_all
  Comment.destroy_all
  Ticket.destroy_all
  User.destroy_all
end

# ──────────────────────────────────────────────────────────────
# Users
# ──────────────────────────────────────────────────────────────
puts "  Creating users..."

agents = [
  { name: "Chioma Okafor",    email: "chioma.agent@tixafrica.com" },
  { name: "Emeka Nwosu",      email: "emeka.agent@tixafrica.com" },
  { name: "Fatima Abubakar",  email: "fatima.agent@tixafrica.com" }
].map do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |u|
    u.name     = attrs[:name]
    u.password = "password123"
    u.role     = :agent
  end
end

customers = [
  { name: "Tunde Adeyemi",       email: "tunde.adeyemi@gmail.com" },
  { name: "Ngozi Eze",           email: "ngozi.eze@yahoo.com" },
  { name: "Kemi Balogun",        email: "kemi.balogun@gmail.com" },
  { name: "Chukwuemeka Obi",     email: "emeka.obi@hotmail.com" },
  { name: "Aisha Mohammed",      email: "aisha.mohammed@gmail.com" }
].map do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |u|
    u.name     = attrs[:name]
    u.password = "password123"
    u.role     = :customer
  end
end

puts "    #{agents.size} agents, #{customers.size} customers"

# ──────────────────────────────────────────────────────────────
# Helper: backdate a record's created_at without touching updated_at
# ──────────────────────────────────────────────────────────────
def stamp(record, time)
  record.update_columns(created_at: time)
end

# ──────────────────────────────────────────────────────────────
# 1. Open tickets — unassigned (freshly submitted, awaiting pickup)
# ──────────────────────────────────────────────────────────────
puts "  Creating open (unassigned) tickets..."

[
  {
    title:       "I cannot log into my account at all",
    description: "Good afternoon, please I have been trying to log into my account since this morning " \
                 "and it keeps showing 'Invalid credentials'. I have reset my password two times already " \
                 "and it is still not working. Kindly help me resolve this as soon as possible.",
    customer:    customers[0],
    age:         2.hours.ago
  },
  {
    title:       "Money was deducted but payment failed — Burna Boy concert",
    description: "Please I need urgent help. I tried to buy 2 tickets for the Burna Boy concert at " \
                 "Eko Convention Centre on Saturday but the payment failed on your platform. However, " \
                 "₦45,000 has already been debited from my GTBank account. Transaction reference: " \
                 "TXN-20240312-9921. Please help me, the concert is on Friday.",
    customer:    customers[1],
    age:         30.minutes.ago
  },
  {
    title:       "Event date on website is different from what my friend sent me",
    description: "Good day, please there is a confusion about the Felabration 2024 event date. " \
                 "The website is showing October 12th but my friend who bought a ticket last week " \
                 "received a confirmation email saying October 15th. Which one is the correct date? " \
                 "We are coming from Abuja so we need to book our transport on time.",
    customer:    customers[2],
    age:         5.hours.ago
  }
].each do |attrs|
  ticket = Ticket.create!(
    title:       attrs[:title],
    description: attrs[:description],
    customer:    attrs[:customer]
  )
  stamp(ticket, attrs[:age])
end

# ──────────────────────────────────────────────────────────────
# 2. Open tickets — assigned, active conversations
# ──────────────────────────────────────────────────────────────
puts "  Creating open (active) tickets..."

# Paystack double charge — multi-turn conversation, still open
billing_ticket = Ticket.create!(
  title:       "Charged twice for the same ticket — Wizkid Homecoming",
  description: "Please I am very frustrated right now. I purchased one ticket for the Wizkid Homecoming " \
               "concert at Lagos but my Paystack history is showing two successful charges of ₦35,000 each " \
               "for the same order (ORD-20240310-5543). That is ₦70,000 gone from my account. " \
               "Kindly refund the extra charge immediately.",
  customer:    customers[3],
  agent:       agents[0]
)
stamp(billing_ticket, 3.days.ago)

[
  { user: agents[0],    body: "Good day Chukwuemeka, thank you for reaching out. I sincerely apologise " \
                              "for this inconvenience. I can confirm I see both transactions on our end. " \
                              "I have already escalated this to our finance team and your refund of ₦35,000 " \
                              "will be processed within 2–3 business days. I will keep you updated.",
    age: 3.days.ago + 4.hours },
  { user: customers[3], body: "Thank you Chioma. Please just to confirm — will the refund go back to my " \
                              "Paystack wallet or back to my Access Bank account directly?",
    age: 3.days.ago + 6.hours },
  { user: agents[0],    body: "The refund will be returned to the original payment source — in this case " \
                              "your Access Bank account. You will also receive an SMS and email confirmation " \
                              "from Paystack once it has been processed. Please bear with us.",
    age: 3.days.ago + 7.hours },
  { user: customers[3], body: "Okay, thank you. I appreciate the quick response. I will wait.",
    age: 3.days.ago + 8.hours }
].each do |c|
  comment = Comment.create!(ticket: billing_ticket, user: c[:user], body: c[:body])
  stamp(comment, c[:age])
end

# Missing e-ticket — resolved conversation but ticket still open
missing_ticket = Ticket.create!(
  title:       "Did not receive e-ticket for Headies Awards 2024",
  description: "Please I bought 2 VIP tickets for the Headies Awards at the Eko Hotel on March 8th " \
               "(order ORD-20240308-1102) and I have not received any email with the tickets. " \
               "I have checked my inbox, spam, and even promotions folder — nothing. " \
               "The event is next week and I am panicking.",
  customer:    customers[4],
  agent:       agents[1]
)
stamp(missing_ticket, 6.days.ago)

[
  { user: agents[1],    body: "Good evening Aisha, I understand how stressful this must be and I am on it " \
                              "right now. Could you please confirm the email address you used during checkout? " \
                              "Sometimes our customers use a different email from their account login.",
    age: 6.days.ago + 2.hours },
  { user: customers[4], body: "Oh! I think I used aisha.work@outlook.com at checkout, not this Gmail address.",
    age: 5.days.ago },
  { user: agents[1],    body: "Found it! The tickets were sent to aisha.work@outlook.com. I have just " \
                              "resent them to that address. Please check and confirm you have received them.",
    age: 5.days.ago + 1.hour },
  { user: customers[4], body: "Emeka I have received them! Thank God! You are a lifesaver, thank you so much!",
    age: 5.days.ago + 3.hours },
  { user: agents[1],    body: "Wonderful! I am glad we sorted it out. Enjoy the Headies — it is going to " \
                              "be a great night!",
    age: 5.days.ago + 3.5.hours }
].each do |c|
  comment = Comment.create!(ticket: missing_ticket, user: c[:user], body: c[:body])
  stamp(comment, c[:age])
end

# ──────────────────────────────────────────────────────────────
# 3. Recently closed tickets (within last month) — appear in recent exports & analytics
# ──────────────────────────────────────────────────────────────
puts "  Creating recently closed tickets..."

[
  {
    title:       "I was given the wrong seat at the Afrobeats Festival",
    description: "Good morning, please I attended the Afrobeats Festival at Tafawa Balewa Square last " \
                 "Saturday and I was seated in section G row 10 but my e-ticket clearly shows section " \
                 "B row 2 which is a premium seat. The security people at the venue were not helpful at all. " \
                 "I paid ₦60,000 for a premium experience and did not get it. I want a refund.",
    customer:    customers[0],
    agent:       agents[2],
    age:         10.days.ago,
    comments: [
      { user: agents[2],    body: "Good morning Tunde, I am truly sorry for this very disappointing experience. " \
                                  "This should not have happened and I completely understand your frustration. " \
                                  "I am escalating this to our venue partnerships team immediately for a formal " \
                                  "investigation. I will personally follow up with you.",
        age: 9.days.ago + 2.hours },
      { user: customers[0], body: "Thank you Fatima. Please how long will this take? The money involved is not small.",
        age: 9.days.ago + 4.hours },
      { user: agents[2],    body: "I completely understand. Our team aims to resolve escalations within " \
                                  "3 business days. I will not allow this to drag. You have my word.",
        age: 8.days.ago },
      { user: agents[2],    body: "Update Tunde: The venue has confirmed that the seating error was entirely " \
                                  "on their end due to a staffing mix-up. We have processed a ₦20,000 goodwill " \
                                  "credit to your Tix Africa wallet. The full event cost refund will follow " \
                                  "within 48 hours. Again, we sincerely apologise.",
        age: 7.days.ago + 1.hour }
    ],
    closed_at: 7.days.ago
  },
  {
    title:       "App is crashing when I try to open my QR code ticket",
    description: "Please every time I try to open my ticket on the Tix Africa app to show the QR code " \
                 "the app just closes by itself. I have tried 3 times already. I am using a Tecno Camon 20 " \
                 "with Android 13. The concert is tomorrow and I am very worried.",
    customer:    customers[1],
    agent:       agents[0],
    age:         14.days.ago,
    comments: [
      { user: agents[0],    body: "Good evening Ngozi, thank you for letting us know urgently. I can confirm " \
                                  "this is a known bug in app version 2.1.0 which affected some Android 13 " \
                                  "devices. We released a fix in version 2.1.1 this afternoon. Please go to " \
                                  "the Play Store now and update the app — it should be working fine after that.",
        age: 14.days.ago + 3.hours },
      { user: customers[1], body: "Chioma I updated it and it opened immediately! I can see my QR code now. " \
                                  "Thank you so much, you saved my night!",
        age: 13.days.ago + 1.hour }
    ],
    closed_at: 13.days.ago
  },
  {
    title:       "Refund not received for cancelled Lagos Jazz Series",
    description: "Good day, I bought tickets for the Lagos Jazz Series in February and the event was " \
                 "cancelled. It has been almost 3 weeks now and I have not seen any refund. " \
                 "I paid ₦25,000 and that is a lot of money. Please what is happening?",
    customer:    customers[2],
    agent:       agents[1],
    age:         20.days.ago,
    comments: [
      { user: agents[1],    body: "Good day Kemi, I sincerely apologise for the delay. I can confirm the " \
                                  "event was officially cancelled on February 20th and refunds were initiated. " \
                                  "Your ₦25,000 refund is in the queue and should reflect within 5–7 business " \
                                  "days. I am keeping an eye on it.",
        age: 19.days.ago },
      { user: customers[2], body: "Emeka it has been 10 days since you said that and still nothing in my account. " \
                                  "This is not fair at all.",
        age: 12.days.ago },
      { user: agents[1],    body: "Kemi I completely understand and I sincerely apologise. I have now escalated " \
                                  "this to our payments team as a priority case. You will receive a confirmation " \
                                  "by close of business tomorrow at the latest.",
        age: 11.days.ago + 2.hours },
      { user: customers[2], body: "The money entered my First Bank account just now. Thank you Emeka, finally!",
        age: 10.days.ago }
    ],
    closed_at: 10.days.ago
  },
  {
    title:       "Promo code DETTY25 is not working at checkout",
    description: "Please I saw the promo code DETTY25 posted on your Instagram page yesterday for " \
                 "Detty December events but when I enter it at checkout it shows 'Invalid promo code'. " \
                 "I even screenshotted the post. Kindly help me apply it.",
    customer:    customers[3],
    agent:       agents[2],
    age:         5.days.ago,
    comments: [
      { user: agents[2],    body: "Good afternoon Chukwuemeka, thank you for the screenshot — very helpful! " \
                                  "I have looked into this. The code DETTY25 expired at midnight on March 1st, " \
                                  "it was only valid during the launch weekend. I have gone ahead and applied " \
                                  "a one-time 15% discount directly to your account as a goodwill gesture " \
                                  "for the inconvenience. It will show automatically at your next checkout.",
        age: 4.days.ago + 2.hours },
      { user: customers[3], body: "Ah okay, I didn't know it had expired. Thank you so much Fatima, " \
                                  "that's very kind of you. God bless you!",
        age: 4.days.ago + 3.hours }
    ],
    closed_at: 4.days.ago
  },
  {
    title:       "Ticket PDF download is not working on my phone",
    description: "Good morning, please every time I click the download button for my ticket PDF on " \
                 "the website it just keeps loading and nothing downloads. I have tried on Chrome and " \
                 "also on Opera Mini. I need to print this ticket before Friday.",
    customer:    customers[4],
    agent:       agents[0],
    age:         8.days.ago,
    comments: [
      { user: agents[0],    body: "Good morning Aisha! Thank you for reaching out. We had a brief technical " \
                                  "issue with our PDF generation service yesterday evening which has since been " \
                                  "fully resolved. Could you please try downloading again now? It should work.",
        age: 8.days.ago + 1.hour },
      { user: customers[4], body: "Chioma it downloaded immediately just now! Thank you so much. " \
                                  "I will go and print it right away.",
        age: 7.days.ago + 4.hours }
    ],
    closed_at: 7.days.ago + 5.hours
  }
].each do |attrs|
  # Create ticket open first so customer comments pass validation
  ticket = Ticket.create!(
    title:       attrs[:title],
    description: attrs[:description],
    customer:    attrs[:customer],
    agent:       attrs[:agent]
  )
  stamp(ticket, attrs[:age])

  attrs[:comments].each do |c|
    comment = Comment.create!(ticket: ticket, user: c[:user], body: c[:body])
    stamp(comment, c[:age])
  end

  # Close after comments are created
  ticket.update_columns(closed_at: attrs[:closed_at])
end

# ──────────────────────────────────────────────────────────────
# 4. Older closed tickets (> 1 month ago) — excluded from recent exports
# ──────────────────────────────────────────────────────────────
puts "  Creating older closed tickets..."

[
  {
    title:       "Please I want to transfer my ticket to my brother",
    description: "Good day, unfortunately I cannot attend the Coke Studio Live Lagos event anymore " \
                 "because of a family emergency in Ibadan. Can I transfer my ticket to my younger " \
                 "brother instead? His name is Biodun Adeyemi.",
    customer:    customers[4],
    agent:       agents[0],
    age:         45.days.ago,
    comments: [
      { user: agents[0],    body: "Good day Aisha, I am sorry to hear about the emergency — I hope all " \
                                  "is well with your family. Yes, ticket transfers are supported! " \
                                  "Biodun just needs to create a free Tix Africa account and then you can " \
                                  "initiate the transfer from the 'My Orders' section on your dashboard.",
        age: 44.days.ago + 2.hours },
      { user: customers[4], body: "It worked! My brother has the ticket now. Thank you so much Chioma, " \
                                  "you people are always very helpful.",
        age: 43.days.ago + 1.hour }
    ],
    closed_at: 43.days.ago
  },
  {
    title:       "My name is spelt wrongly on the e-ticket",
    description: "Please good afternoon, my name on the e-ticket is showing as 'Chukwueeka' instead " \
                 "of 'Chukwuemeka'. Will the security at the gate reject my ticket because of this? " \
                 "I am very worried. The event is at Eko Hotel.",
    customer:    customers[3],
    agent:       agents[1],
    age:         60.days.ago,
    comments: [
      { user: agents[1],    body: "Good afternoon Chukwuemeka, please do not worry at all. The gate staff " \
                                  "at Eko Hotel scan the QR code — they do not check the name on the ticket. " \
                                  "A small typo like this will not affect your entry in any way. " \
                                  "I have also corrected the spelling on our system so if you download " \
                                  "the ticket again it will show the right name.",
        age: 59.days.ago + 3.hours }
    ],
    closed_at: 59.days.ago
  },
  {
    title:       "Group discount for Calabar Carnival — we are 15 people",
    description: "Hello, please my company is planning to attend the Calabar Carnival this December " \
                 "and we will be a group of 15 people. Do you offer any group discount or corporate " \
                 "rate? We are all coming from Lagos.",
    customer:    customers[0],
    agent:       agents[2],
    age:         35.days.ago,
    comments: [
      { user: agents[2],    body: "Good morning Tunde, that sounds like a wonderful outing! " \
                                  "Yes, we do offer group rates for parties of 10 and above. " \
                                  "For a group of 15 you will qualify for a 12% discount. " \
                                  "Please send an email to groups@tixafrica.com with the event name, " \
                                  "your group size, and preferred ticket category. Our team will " \
                                  "send you a custom promo code within 24 hours.",
        age: 34.days.ago + 1.hour },
      { user: customers[0], body: "Wow, 12% is not bad at all! I have sent the email just now. " \
                                  "Thank you Fatima, we appreciate it!",
        age: 34.days.ago + 4.hours }
    ],
    closed_at: 34.days.ago
  }
].each do |attrs|
  ticket = Ticket.create!(
    title:       attrs[:title],
    description: attrs[:description],
    customer:    attrs[:customer],
    agent:       attrs[:agent]
  )
  stamp(ticket, attrs[:age])

  attrs[:comments].each do |c|
    comment = Comment.create!(ticket: ticket, user: c[:user], body: c[:body])
    stamp(comment, c[:age])
  end

  ticket.update_columns(closed_at: attrs[:closed_at])
end

# ──────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────
total_closed  = Ticket.where.not(closed_at: nil)
recent_closed = Ticket.recently_closed

puts ""
puts "Seed complete!"
puts "  Users:    #{User.count} (#{User.agent.count} agents, #{User.customer.count} customers)"
puts "  Tickets:  #{Ticket.count} total"
puts "              #{Ticket.open_tickets.count} open"
puts "              #{recent_closed.count} recently closed (within last month)"
puts "              #{total_closed.where.not(id: recent_closed.select(:id)).count} older closed"
puts "  Comments: #{Comment.count}"
