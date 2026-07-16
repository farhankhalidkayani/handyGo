# Handy Go — Complete System Flow (Customer + Worker + Admin + Safety)

> Ye document Handy Go ke poore system ka combined flow hai — Customer App, Worker App, Admin Panel, real-time connection, booking status system, aur SOS/Safety system sab ek jagah. Developer isko reference ke tor par use kar ke pura backend + frontend flow implement kar sake.

---

## 0. System Overview

Handy Go ek **Careem/InDrive-style on-demand home service marketplace** hai jisme teen apps hain:

1. **Customer App**
2. **Worker App**
3. **Admin Panel**

Teeno apps **real-time sync** mein kaam karte hain — kisi bhi app mein action hote hi doosri apps turant update hoti hain (Appwrite Realtime ke zariye).

---

## 1. Customer App Flow

### A. Signup and Onboarding

```
Splash Screen
→ Language Selection
→ Location Permission
→ Login / Signup
→ Email OTP Verification
→ Profile Setup
→ Home Screen
```

**Customer Profile fields:**
- Name
- Profile picture
- Phone number
- Email
- Default address
- Current location
- Emergency contact
- Saved addresses: Home, Office, Other

**Welcome message (signup ke baad):**
> Welcome to Handy Go, Ammar! What service do you need today?

---

### B. Professional Home Screen

Home screen sections:
- Current location
- Search bar — "What service do you need?"
- AI Assistant button
- Service categories: Plumbing, Electrical, Carpentry, Cleaning, AC Repair, Appliance Repair, Emergency Service
- Popular Services
- Previous Bookings
- Recommended for You
- Active Booking card

**Example dynamic greeting:**
> Good evening, Ammar 👋
> 24 verified workers are available near Johar Town.

---

### C. Service Request Creation (3 Methods)

**Method 1 — Manual Selection**
```
Select Category
→ Select Service
→ Add Problem Description
→ Upload Images
→ Select Address
→ Choose Date and Time
→ AI Price Estimation
→ Confirm Request
```
Example output:
```
Category: Carpentry
Issue: Sofa ka leg toot gaya hai
Estimated Price: Rs. 1,500 – 2,300
Estimated Duration: 1–2 hours
Workers Nearby: 8
```

**Method 2 — AI Chatbot (Conversational)**
Customer natural language mein likhta hai, AI category detect kar ke follow-up questions puchta hai, image mangwata hai, aur final estimate deta hai. AI ka response professional aur ChatGPT-style conversational hona chahiye — detected category, problem summary, estimated price, duration, confidence, suggested solution, safety instructions, aur "Book Service" button ke saath.

**Method 3 — Image Recognition**
```
Upload Picture
→ AI detects possible category
→ Customer confirms category
→ AI asks necessary questions
→ Price estimate
→ Booking request
```
Agar AI wrong category detect kare to customer ke paas **"Change Category"** option zaroor ho.

---

### D. InDrive-Style Worker Offers

Request create hone ke baad nearby workers ko notification jati hai:
> Finding verified workers near you...
> 8 workers notified · 3 workers viewing your request

Har worker offer mein:
- Name, Rating, Jobs Completed, Distance, Arrival Time, Quote

Customer compare kar sakta hai: Price, Rating, Distance, Completed jobs, Experience, Arrival time, Reviews, Verified badge, Profile picture — aur options: **Accept offer / Chat / Call**.

System "Best Match" recommend kare (lowest price force nahi karna):
> Best Match — Good rating, reasonable price and fastest arrival.

---

### E. Worker Selection and Live Tracking

```
Offer Accepted
→ Worker notified
→ Worker starts travelling
→ Live tracking
→ Worker arrives
→ Customer verifies worker
→ Job starts
```

**Tracking screen elements:** Live map, worker moving marker, name/picture, vehicle info, ETA, Call, Chat, Cancel booking, **SOS button**, Booking ID, service details.

**Real-time status list:**
```
Worker Assigned → Worker Preparing → Worker On The Way → Worker Nearby
→ Worker Arrived → Service Started → Service In Progress
→ Service Completed → Payment Pending → Completed
```
Har status timestamp ke saath: *"Worker arrived at 7:42 PM."*

---

### F. Secure Service Start (OTP Verification)

Worker sirf arrival ke baad hi service start kar sakta hai. Customer app par 4-digit OTP show hota hai (e.g. **4821**), worker enter karta hai:
```
OTP Verified → Service Started → Timer Started
```
Isse fake bookings aur fake completions rukti hain.

---

### G. Service in Progress

Customer live progress card dekhta hai (Started at, Duration, Worker name). Agar worker additional material cost add karna chahe (e.g. Rs. 450 for pipe), to customer ko approval request jati hai — **customer approval ke baghair final bill change nahi ho sakta.**

---

### H. Completion and Payment

```
Worker Marks Job Complete
→ Customer receives completion request
→ Customer confirms
→ Final invoice generated
→ Payment
→ Rating and review
```

**Payment methods:** Cash on Delivery, JazzCash, Easypaisa, Wallet, Debit/Credit card (future).

**Invoice example:**
```
Service Charges: Rs. 1,850
Material Charges: Rs. 450
Platform Fee: Rs. 100
Discount: Rs. 200
Total: Rs. 2,200
```

Post-completion actions: Download invoice, Rate worker, Add review, Add tip, Rebook worker, Report problem, Warranty/support request.

---

## 2. Worker App Flow

### A. Worker Registration

```
Signup → Email OTP → Personal Information → CNIC Upload → Selfie Verification
→ Skill Selection → Experience → Service Area → Documents Upload
→ Bank/Wallet Details → Admin Verification
```

**Worker status states:** Profile Incomplete, Documents Under Review, Approved, Rejected, Suspended.

> Worker approve hone se pehle koi booking accept nahi kar sakta.

Screen message:
> Your documents are being reviewed. Expected verification time: within 24 hours.

---

### B. Worker Dashboard

Dashboard shows: Online/offline toggle, Today's earnings, Available requests, Active job, Completed jobs, Rating, Wallet balance, Weekly performance, Notifications, Profile completeness.

Availability states: **Offline / Online / Busy / Break** (offline worker ko koi request nahi milti).

---

### C. Incoming Booking Request

Request card mein: Category, Distance, Customer Estimate, Problem, Images, Requested Time.

Worker options: **Accept Estimate / Send Custom Offer / Decline / Ask Customer**

Custom offer ke saath reason dena hota hai. **Worker ko customer ka exact phone number offer accept hone se pehle show nahi hota** (masked call system).

---

### D. Offer Accepted → Navigation

```
Booking Confirmed → Worker sees customer location → Navigation starts
→ Worker marks On The Way → Worker arrives
```

Worker screen: Open Google Maps, Customer chat, Masked call, Problem details, Uploaded images, Price quote, Address, Safety instructions.

---

### E. Service Start and Progress

```
Worker Arrived → Enter Customer OTP → Service Started → Start Timer
```

Worker actions during service: before-service photos, material requirements, request additional payment, job notes, progress status updates, contact customer/support.

> Worker customer approval ke baghair additional price add nahi kar sakta.

---

### F. Job Completion

```
Upload After-Service Images → Add Work Summary → Enter Material Cost
→ Request Completion → Customer Confirms → Payment Received
```

**Earnings breakdown:**
```
Job Earnings: Rs. 1,850
Material Charges: Rs. 450
Platform Commission: Rs. 185
Net Earnings: Rs. 1,665
```

Wallet section: Available balance, Pending balance, Withdraw, Transaction history, Platform commission, Bonuses, Penalties.

---

## 3. Admin Panel Flow

### A. Admin Dashboard

**Stat cards:** Total customers, Total workers, Workers pending verification, Active bookings, Completed bookings, Cancelled bookings, Today's revenue, Pending payments, Open disputes, SOS alerts, Average rating, Online workers.

**Live section example:**
```
18 Active Jobs · 42 Online Workers · 6 Workers Travelling
9 Services In Progress · 3 Payments Pending
```

**Charts:** Daily bookings, Revenue, Most used services, Cancellation rate, Worker performance, Customer growth, City-wise bookings.

---

### B. Worker Verification

Admin reviews: CNIC front/back, Selfie, Address, Phone/email, Skills, Certificates, Experience, Background verification status, Previous rejection reasons.

Actions: **Approve / Reject / Request More Information / Suspend / Block** — har action ka reason required hai.

---

### C. Booking Management

Booking detail page mein sab ek jagah: Customer info, Worker info, Timeline, Request, AI estimate, Worker quote, Additional charges, Chat history, Payment details, Location, Images, Rating, Complaint, Audit history.

Admin actions: Reassign Worker, Cancel Booking, Issue Refund, Contact Customer/Worker, Resolve Dispute, Apply Penalty.

---

### D. Live Operations Map

Map par: Online workers, Active bookings, Travelling workers, Emergency requests, Worker locations, Service heatmap.

Marker statuses: **Available / Travelling / Arrived / Working / SOS / Offline**

> SOS request screen ke top par red alert ke saath show hoti hai.

---

### E. Payments and Finance

Panel: Customer payments, Worker earnings, Platform commission, Refunds, Pending withdrawals, Failed payments, Wallet transactions, Promo discounts, Tax/service fee — har transaction ka full audit log.

---

### F. Disputes and Complaints

```
Complaint Created → Admin Review → Evidence Requested
→ Customer/Worker Response → Decision → Refund/Penalty → Closed
```

Admin ko before/after images, chat, location timestamps aur payment records dikhte hain.

---

## 4. SOS / Emergency Safety System

> **Important:** SOS sirf Customer side par nahi, **Customer aur Worker dono apps mein** hona chahiye, kyunki emergency ya fraud dono taraf se ho sakta hai.

### A. Customer App — SOS

**Use cases:** Worker threatening/aggressive behavior, identity mismatch, extra money zabardasti maangna, theft, medical emergency, fake location, payment demand without completing job.

```
Customer presses SOS
→ Confirmation screen opens
→ Emergency type select karta hai
→ Current location automatically attach hoti hai
→ Booking, worker aur customer details admin ko jati hain
→ Emergency contacts ko alert milta hai
→ Admin dashboard par red alert show hota hai
```

**Emergency types:** Personal Safety Threat, Fraud/Overcharging, Worker Identity Mismatch, Theft or Property Damage, Medical Emergency, Harassment, Other Emergency

**Buttons:** Call Emergency Services, Alert Handy Go Admin, Share Live Location, Call Emergency Contact, Report Fraud

---

### B. Worker App — SOS

**Use cases:** Customer threatening behavior, unsafe location, payment refusal, fake complaint/fraud, robbery risk, inappropriate behavior, medical emergency, unauthorized extra work forced.

```
Worker presses SOS
→ Emergency category select karta hai
→ Current location and booking automatically attach hoti hai
→ Customer details admin ko jati hain
→ Admin ko immediate alert milta hai
→ Worker emergency contact ko location share hoti hai
```

**Emergency options:** Unsafe Customer, Payment Fraud, Threat or Violence, Harassment, Robbery Risk, Medical Emergency, Fake Booking, Other Emergency

---

### C. SOS vs Report Fraud — Alag Rakho

| | **SOS** | **Report Fraud** |
|---|---|---|
| Kab use ho | Immediate danger (threat, violence, harassment, robbery, medical, unsafe location) | Non-immediate financial/account issue |
| Response | Instant admin alert + live location + emergency actions | Normal investigation workflow |
| Examples | Physical threat, medical emergency | Fake booking, overcharging, false completion, fake docs, impersonation, fake review |

**Fraud report workflow:**
```
Report Submitted → Evidence Uploaded → Account Temporarily Flagged
→ Admin Investigation → Customer/Worker Response → Decision
→ Refund, Warning, Suspension or Ban
```

---

### D. SOS Button Placement

**Customer App:** Active booking screen, Worker tracking screen, Service in-progress screen, Chat screen, Profile → Safety Center

**Worker App:** Accepted booking screen, Navigation screen, Customer location screen, Service in-progress screen, Chat screen, Profile → Safety Center

Active service ke dauran floating red button:
```
🆘 SOS
```
Accidental press avoid karne ke liye: **"Press and hold for 3 seconds"** ya **"Swipe to activate SOS"**

---

### E. SOS Data Captured

```
SOS ID
Booking ID
Raised By: Customer / Worker
Customer ID
Worker ID
Emergency Type
Current GPS Location
Time and Date
Booking Status
Recent Chat Messages
Recent Location History
Uploaded Evidence
Device Information
Audio/Video Evidence (only if voluntarily provided)
Admin Response Status
```

> User ko clearly batana zaroori hai ke recording/media tabhi upload ho jab woh khud choose kare aur applicable law/privacy policy allow kare.

---

### F. Admin — SOS Control Center

Top par red emergency alert banner:
```
URGENT SOS ALERT
Raised By: Worker
Reason: Unsafe Customer
Booking: HG-2026-1054
Location: Johar Town, Lahore
Time: 9:32 PM
```

**Admin actions:** Open Live Location, Call Customer, Call Worker, Contact Emergency Services, Notify Emergency Contact, Pause Booking, Block Payment, Cancel Booking, Suspend Account, Assign Support Agent, Mark Safe, Close Incident

**Incident timeline example:**
```
9:32 PM — SOS activated
9:33 PM — Admin opened alert
9:34 PM — Worker contacted
9:36 PM — Booking paused
9:40 PM — Situation marked safe
```

---

### G. False SOS Protection

Direct ban mat karo — pehle investigation:
```
First accidental misuse    → Warning
Repeated misuse             → Temporary restriction
Intentional false reports   → Account suspension
Serious misuse               → Permanent ban
```

SOS activate karne wale user par cancellation charges automatically na lagao jab tak admin incident review na kar le.

### H. Final Safety Structure

```
Customer App
├── SOS Emergency
├── Report Worker
└── Report Fraud

Worker App
├── SOS Emergency
├── Report Customer
└── Report Payment Fraud

Admin Panel
├── Live SOS Alerts
├── Fraud Investigations
├── Evidence and Timeline
├── Account Actions
└── Incident Resolution
```

---

## 5. Real-Time Connection Between All Three Apps

Sabse important part: **ek app mein action ho to doosri apps instantly update hon.**

```
Customer creates booking
↓
Worker receives request instantly
↓
Worker sends offer
↓
Customer receives offer instantly
↓
Customer accepts
↓
Worker receives confirmation
↓
Admin dashboard active booking show karta hai
```

**Appwrite Realtime se listen karne wali collections:**
```
bookings
worker_offers
booking_status_history
messages
notifications
transactions
worker_locations
disputes
sos_alerts
```

---

## 6. Common Booking Status System

Customer, Worker, Admin — teeno mein **same status names** use karo:

```
draft
searching_workers
offers_received
worker_selected
confirmed
worker_on_the_way
worker_arrived
service_started
in_progress
completion_requested
payment_pending
completed
cancelled
disputed
refunded
```

Har status change par history document create ho:
```
Status: worker_on_the_way
Changed By: Worker
Date: 15 July 2026
Time: 8:10 PM
```
Isse admin ko complete audit trail milta hai.

---

## 7. Making the App Feel Like a Real Virtual Environment

### Realistic Movement & Feedback
Har button press ke baad proper response: "Request sent successfully", "Notifying nearby workers", "Worker is viewing your request", "New offer received", "Worker is 5 minutes away", "Worker has arrived", etc.

### Loading States
Blank screen ke bajaye: Skeleton cards, Animated worker search, Map loading indicator, Upload progress, Payment processing state.

### Empty States
> "No worker offers received yet. We are expanding the search radius."

### Error States
> "We could not confirm your payment. No amount was deducted. Please try again."

### Notifications by Role

**Customer:** New worker offer, Worker selected, Worker on the way, Worker arrived, Additional cost request, Service completion, Payment confirmation

**Worker:** New job nearby, Offer accepted, Customer message, Payment received, Document expiring, Admin announcement

**Admin:** New worker registration, High-value booking, Failed payment, SOS alert, Complaint created, Suspicious activity

---

## 8. UI / Design Consistency Rules

- Same brand colors, button radius, icon style, typography, spacing across all 3 apps
- Clear status colors
- Professional illustrations, proper profile pictures, verified badges
- Responsive layouts
- Har screen mein: Main heading, Small supporting text, Primary action, Secondary action, Clear status, Helpful empty/error state

**Action-oriented button naming:**
| Generic | Professional |
|---|---|
| Submit | Book Now |
| Done | Send Offer |
| OK | Confirm Completion |
| Add Price | Request Additional Cost |

---

## 9. Demo Mode (FYP Presentation)

Separate Demo Environment with realistic test accounts:
```
Customer: Ammar
Worker: Ali Electrician
Admin: Handy Go Admin
```

**Demo scenario script:**
```
Customer requests AC repair
→ AI estimates Rs. 2,000–3,500
→ Three workers send offers
→ Customer selects Ali
→ Worker travels on map
→ OTP starts service
→ Worker requests Rs. 500 material cost
→ Customer approves
→ Service completes
→ Online payment
→ Customer gives 5-star rating
→ Admin sees completed transaction
```

> Demo mode mein fake actions clearly test/demo data honi chahiye, lekin system ka behavior real backend jaisa lagna chahiye.

---

*Document merged for developer handoff — Handy Go FYP project.*
