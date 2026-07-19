require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const client = new sdk.Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new sdk.Databases(client);
const DB = process.env.APPWRITE_DB || 'handygo';

const CUSTOMER_USER_ID = '6a5bd33c24220eb0b739'; // users.$id for rj.farhan4232@gmail.com
const CUSTOMER_PROFILE_ID = '6a5bd33d0b3b01fd437f'; // customer_profiles.$id
const WORKER_USER_ID = '6a5bdd6226930073b470'; // users.$id for rj.farhan4242@gmail.com
const WORKER_PROFILE_ID = '6a5bdd62a96f03c4fd92'; // worker_profiles.$id

const CATEGORIES = {
  plumbing: '6a58f900002cca3aa386',
  electrical: '6a58f9010028eea5ba3f',
  carpentry: '6a58f902000c151d2d2e',
  cleaning: '6a58f902002cfe332c81',
  acRepair: '6a58f903001091e02b5a',
  applianceRepair: '6a58f903003397e13d7f',
};

const ADDR_LAT = 31.420793531278;
const ADDR_LNG = 74.354988096653;

async function createBooking(fields) {
  return databases.createDocument(DB, 'bookings', sdk.ID.unique(), {
    customerId: CUSTOMER_USER_ID,
    workerId: WORKER_USER_ID,
    detectedByAI: true,
    problemImages: [],
    addressText: 'House 12, Street 5, Gulberg III, Lahore',
    lat: ADDR_LAT,
    lng: ADDR_LNG,
    aiUrgency: 'normal',
    additionalCharges: 0,
    pendingAdditionalCharge: 0,
    paused: false,
    paymentBlocked: false,
    ...fields,
  });
}

async function addHistory(bookingId, entries) {
  for (const e of entries) {
    await databases.createDocument(DB, 'booking_status_history', sdk.ID.unique(), {
      bookingId,
      changedByRole: 'system',
      changedById: 'seed',
      ...e,
    });
  }
}

async function notify(userId, role, fields) {
  return databases.createDocument(DB, 'notifications', sdk.ID.unique(), {
    userId,
    role,
    read: false,
    ...fields,
  });
}

(async () => {
  console.log('Enriching customer profile...');
  await databases.updateDocument(DB, 'customer_profiles', CUSTOMER_PROFILE_ID, {
    defaultAddress: 'House 12, Street 5, Gulberg III, Lahore',
    savedAddresses: ['House 12, Street 5, Gulberg III, Lahore', 'Office 4B, MM Alam Road, Lahore'],
    emergencyContactName: 'Ayesha Farhan',
    emergencyContactPhone: '+923001234567',
    currentLat: ADDR_LAT,
    currentLng: ADDR_LNG,
  });

  console.log('Creating completed booking (Electrical, rated)...');
  const b1 = await createBooking({
    categoryId: CATEGORIES.electrical,
    problemText: 'Living room ceiling fan making a loud grinding noise and running slow',
    aiEstimateMin: 600,
    aiEstimateMax: 1800,
    aiDurationMins: 60,
    aiConfidence: 0.86,
    aiSuggestedSolution: 'A verified worker will inspect the fan motor and capacitor.',
    finalQuote: 950,
    status: 'completed',
    otp: '4821',
    ratingGiven: 4,
    reviewText: 'Quick and tidy work, fan is silent now. Slightly late arrival.',
    workSummary: 'Replaced worn capacitor and lubricated motor bearing. Tested for 10 minutes, no noise.',
  });
  await addHistory(b1.$id, [
    { status: 'confirmed', timestamp: '2026-07-14T09:15:00.000+00:00' },
    { status: 'in_progress', timestamp: '2026-07-14T09:45:00.000+00:00' },
    { status: 'completed', timestamp: '2026-07-14T10:40:00.000+00:00' },
  ]);
  await databases.createDocument(DB, 'transactions', sdk.ID.unique(), {
    bookingId: b1.$id,
    customerId: CUSTOMER_USER_ID,
    workerId: WORKER_USER_ID,
    serviceCharges: 950,
    materialCharges: 0,
    platformFee: 95,
    discount: 0,
    total: 950,
    method: 'cod',
    status: 'completed',
    commission: 95,
    netToWorker: 855,
  });

  console.log('Creating completed booking (Cleaning, rated)...');
  const b2 = await createBooking({
    categoryId: CATEGORIES.cleaning,
    problemText: 'Deep cleaning needed for 2-bedroom apartment before guests arrive',
    aiEstimateMin: 2000,
    aiEstimateMax: 3500,
    aiDurationMins: 150,
    aiConfidence: 0.79,
    aiSuggestedSolution: 'A verified worker will bring cleaning supplies and equipment.',
    finalQuote: 2800,
    status: 'completed',
    otp: '1093',
    ratingGiven: 5,
    reviewText: 'Excellent, spotless clean. Highly recommend.',
    workSummary: 'Full deep clean including kitchen, bathrooms, floors and windows.',
  });
  await addHistory(b2.$id, [
    { status: 'confirmed', timestamp: '2026-07-16T07:30:00.000+00:00' },
    { status: 'in_progress', timestamp: '2026-07-16T08:00:00.000+00:00' },
    { status: 'completed', timestamp: '2026-07-16T10:35:00.000+00:00' },
  ]);
  await databases.createDocument(DB, 'transactions', sdk.ID.unique(), {
    bookingId: b2.$id,
    customerId: CUSTOMER_USER_ID,
    workerId: WORKER_USER_ID,
    serviceCharges: 2800,
    materialCharges: 0,
    platformFee: 280,
    discount: 0,
    total: 2800,
    method: 'cod',
    status: 'completed',
    commission: 280,
    netToWorker: 2520,
  });

  console.log('Creating an active in-progress booking (AC Repair)...');
  const b3 = await createBooking({
    categoryId: CATEGORIES.acRepair,
    problemText: 'AC unit not cooling, blowing warm air since yesterday',
    aiEstimateMin: 1200,
    aiEstimateMax: 4000,
    aiDurationMins: 90,
    aiConfidence: 0.82,
    aiSuggestedSolution: 'A verified worker will check refrigerant levels and compressor.',
    finalQuote: 1500,
    status: 'in_progress',
    otp: '7734',
    ratingGiven: null,
    reviewText: '',
    workSummary: '',
  });
  await addHistory(b3.$id, [
    { status: 'confirmed', timestamp: '2026-07-19T08:00:00.000+00:00' },
    { status: 'worker_on_the_way', timestamp: '2026-07-19T08:05:00.000+00:00' },
    { status: 'worker_arrived', timestamp: '2026-07-19T08:30:00.000+00:00' },
    { status: 'in_progress', timestamp: '2026-07-19T08:35:00.000+00:00' },
  ]);
  await notify(CUSTOMER_USER_ID, 'customer', {
    type: 'booking_update',
    title: 'Worker has started the job',
    body: 'Your AC Repair booking is now in progress.',
    bookingId: b3.$id,
  });
  await notify(WORKER_USER_ID, 'worker', {
    type: 'booking_update',
    title: 'Job started',
    body: 'You marked the AC Repair job as in progress.',
    bookingId: b3.$id,
  });

  console.log('Creating a searching-for-workers booking with an offer (Plumbing)...');
  const b4 = await createBooking({
    categoryId: CATEGORIES.plumbing,
    workerId: '',
    problemText: 'Kitchen tap dripping constantly, water pressure also low',
    aiEstimateMin: 500,
    aiEstimateMax: 1500,
    aiDurationMins: 45,
    aiConfidence: 0.75,
    aiSuggestedSolution: 'A verified worker will assess and fix the issue.',
    finalQuote: null,
    status: 'offers_received',
    otp: '',
    ratingGiven: null,
    reviewText: '',
    workSummary: '',
  });
  await addHistory(b4.$id, [
    { status: 'searching_workers', timestamp: '2026-07-19T11:00:00.000+00:00' },
    { status: 'offers_received', timestamp: '2026-07-19T11:04:00.000+00:00' },
  ]);
  await databases.createDocument(DB, 'worker_offers', sdk.ID.unique(), {
    bookingId: b4.$id,
    workerId: WORKER_PROFILE_ID,
    quote: 850,
    etaMins: 20,
    distanceKm: 3.2,
    message: 'Can fix the tap and check pressure valve today.',
    reason: '',
    status: 'pending',
    isBestMatch: true,
    flaggedSuspicious: false,
  });
  await notify(CUSTOMER_USER_ID, 'customer', {
    type: 'offer_received',
    title: 'New offer received',
    body: 'A worker sent you a quote for your Plumbing booking.',
    bookingId: b4.$id,
  });

  console.log('Creating a cancelled booking (Carpentry, history)...');
  const b5 = await createBooking({
    categoryId: CATEGORIES.carpentry,
    problemText: 'Wardrobe door hinge broken, needs replacement',
    aiEstimateMin: 400,
    aiEstimateMax: 1200,
    aiDurationMins: 40,
    aiConfidence: 0.7,
    aiSuggestedSolution: 'A verified worker will assess and fix the issue.',
    finalQuote: null,
    status: 'cancelled',
    otp: '',
    ratingGiven: null,
    reviewText: '',
    workSummary: '',
  });
  await addHistory(b5.$id, [
    { status: 'searching_workers', timestamp: '2026-07-12T15:00:00.000+00:00' },
    { status: 'cancelled', changedByRole: 'customer', changedById: CUSTOMER_USER_ID, note: 'Customer cancelled - found alternative', timestamp: '2026-07-12T15:20:00.000+00:00' },
  ]);

  console.log('Adding a worker wallet withdrawal record...');
  await databases.createDocument(DB, 'wallet_withdrawals', sdk.ID.unique(), {
    workerId: WORKER_PROFILE_ID,
    amount: 2000,
    status: 'completed',
  });

  console.log('Updating worker_profiles jobsCompleted count...');
  await databases.updateDocument(DB, 'worker_profiles', WORKER_PROFILE_ID, {
    jobsCompleted: 3, // 1 pre-existing + 2 new completed bookings
    pendingBalance: 1275, // half of in-progress job's quote, illustrative
  });

  console.log('Updating customer_profiles totalBookings count...');
  await databases.updateDocument(DB, 'customer_profiles', CUSTOMER_PROFILE_ID, {
    totalBookings: 5, // 1 pre-existing + 4 new
  });

  console.log('\nDone. Created bookings:');
  console.log('  completed (Electrical, rated 4):', b1.$id);
  console.log('  completed (Cleaning, rated 5):', b2.$id);
  console.log('  in_progress (AC Repair):', b3.$id);
  console.log('  offers_received (Plumbing, has 1 offer):', b4.$id);
  console.log('  cancelled (Carpentry):', b5.$id);
})().catch((e) => {
  console.error('SEED FAILED:', e.message);
  process.exit(1);
});
