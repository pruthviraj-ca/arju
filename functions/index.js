const functions = require("firebase-functions");
const admin = require("firebase-admin");
const twilio = require("twilio");

admin.initializeApp();

/**
 * HTTP Endpoint: Generate Twilio capability token for the authenticated CRM user.
 * Expects: Authorization Bearer token (Firebase ID Token)
 */
exports.twilioAccessToken = functions.https.onRequest(async (req, res) => {
  // CORS setup
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Max-Age", "3600");
    return res.status(204).send("");
  }

  try {
    // 1. Verify Authentication Token
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing or malformed Authorization header" });
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const uid = decodedToken.uid;

    if (!uid) {
      return res.status(401).json({ error: "Invalid user token" });
    }

    // 2. Fetch User Twilio config from Firestore
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User profile not found" });
    }

    const userData = userDoc.data();
    const twilioConfig = userData.twilioConfig;

    if (!twilioConfig || !twilioConfig.enabled) {
      return res.status(400).json({ error: "Twilio calling is not enabled in your profile settings." });
    }

    const { accountSid, apiKeySid, apiSecret, twimlAppSid } = twilioConfig;
    if (!accountSid || !apiKeySid || !apiSecret || !twimlAppSid) {
      return res.status(400).json({ error: "Twilio calling configuration is incomplete in your profile settings." });
    }

    // 3. Generate Twilio Access Token
    const AccessToken = twilio.jwt.AccessToken;
    const VoiceGrant = AccessToken.VoiceGrant;

    // Use API Key & Secret for security instead of master auth token
    const token = new AccessToken(
      accountSid,
      apiKeySid,
      apiSecret,
      { identity: `client_${uid}` }
    );

    const voiceGrant = new VoiceGrant({
      outgoingApplicationSid: twimlAppSid,
      incomingAllow: true, // Allow incoming call capability if needed later
    });

    token.addGrant(voiceGrant);

    return res.json({ token: token.toJwt() });
  } catch (err) {
    console.error("Error generating access token:", err);
    return res.status(500).json({ error: err.message || "Internal Server Error" });
  }
});

/**
 * HTTP Webhook: Twilio makes a POST to this webhook when a client call connects.
 * Generates TwiML instructing Twilio to dial the destination phone number.
 */
exports.twilioVoiceWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const { From, To } = req.body;
    console.log(`Call request received: From ${From} -> To ${To}`);

    if (!To) {
      return res.status(400).send("<Response><Reject reason='busy'/></Response>");
    }

    // 1. Resolve Caller ID dynamically from the user's Firestore profile
    let callerId = "";
    
    // Twilio formats client identities as "client:client_UID"
    if (From && From.startsWith("client:client_")) {
      const uid = From.replace("client:client_", "");
      try {
        const userDoc = await admin.firestore().collection("users").doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.twilioConfig && userData.twilioConfig.callerId) {
            callerId = userData.twilioConfig.callerId;
            console.log(`Resolved callerId from database: ${callerId}`);
          }
        }
      } catch (dbErr) {
        console.error("Failed to query Firestore for callerId:", dbErr);
      }
    }

    // Fallback: Check if callerId was provided as a query parameter (webhook?callerId=+1...)
    if (!callerId && req.query.callerId) {
      callerId = req.query.callerId;
    }

    if (!callerId) {
      console.warn("No Caller ID found. Outgoing call might fail.");
    }

    // 2. Generate TwiML XML
    const VoiceResponse = twilio.twiml.VoiceResponse;
    const response = new VoiceResponse();
    
    // Dial outward using Twilio
    const dial = response.dial({ callerId: callerId });
    dial.number(To);

    res.type("text/xml");
    return res.send(response.toString());
  } catch (err) {
    console.error("Webhook error:", err);
    res.type("text/xml");
    return res.send("<Response><Say>An internal error occurred during the call.</Say></Response>");
  }
});

/**
 * HTTP Endpoint: Get count of follow-ups scheduled on a specific date for an agent.
 * GET /api/leads/followup-count?date=YYYY-MM-DD&agent_id=X&exclude_lead_id=Y
 */
exports.followupCount = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Max-Age", "3600");
    return res.status(204).send("");
  }

  try {
    const { date, agent_id, exclude_lead_id } = req.query;

    if (!date || !agent_id) {
      return res.status(400).json({ error: "Missing date or agent_id query parameter" });
    }

    const leadsRef = admin.firestore().collection("users").doc(agent_id).collection("leads");
    const query = leadsRef.where("followUpDate", "==", date);
    
    const snapshot = await query.count().get();
    let count = snapshot.data().count;

    if (exclude_lead_id) {
      const leadDoc = await leadsRef.doc(exclude_lead_id).get();
      if (leadDoc.exists && leadDoc.data().followUpDate === date) {
        count = Math.max(0, count - 1);
      }
    }

    return res.json({ count });
  } catch (err) {
    console.error("Error checking follow-up count:", err);
    return res.status(500).json({ error: err.message || "Internal Server Error" });
  }
});

/**
 * Firestore Trigger: Duplicate new documents in the user's leads collection
 * to a secondary top-level leads_archive collection for redundancy.
 */
exports.archiveNewLead = functions.firestore
  .document("users/{userId}/leads/{leadId}")
  .onCreate(async (snapshot, context) => {
    const leadData = snapshot.data();
    const leadId = context.params.leadId;
    const userId = context.params.userId;

    console.log(`Archiving new lead created: Lead ID = ${leadId}, User ID = ${userId}`);

    try {
      await admin.firestore().collection("leads_archive").doc(`${userId}_${leadId}`).set({
        ...leadData,
        originalLeadId: leadId,
        agentId: userId,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Successfully archived lead ${leadId} for user ${userId}`);
    } catch (error) {
      console.error(`Failed to archive lead ${leadId} for user ${userId}:`, error);
    }
  });

/**
 * HTTP Endpoint: Receive real-time webhooks from MagicBricks when a lead is generated.
 * POST /magicbricksWebhook?agent_id=AGENT_UID
 */
exports.magicbricksWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed. Use POST." });
  }

  try {
    const { agent_id } = req.query;
    if (!agent_id) {
      console.error("Missing agent_id query parameter in webhook URL");
      return res.status(400).json({ error: "Missing agent_id query parameter." });
    }

    const payload = req.body || {};
    console.log("Received MagicBricks Webhook Payload:", JSON.stringify(payload));

    const clientName = payload.name || payload.Name || payload.clientName || payload.fullname || "MagicBricks Lead";
    const phone = payload.phone || payload.Phone || payload.mobile || payload.Mobile || "";
    const email = payload.email || payload.Email || "";
    const property = payload.property || payload.Property || payload.projectId || payload.project || "Any";

    if (!phone) {
      console.error("Missing phone number in webhook payload");
      return res.status(400).json({ error: "Invalid payload. Phone number is required." });
    }

    const leadsRef = admin.firestore().collection("users").doc(agent_id).collection("leads");

    // Check for duplicate
    const duplicateQuery = await leadsRef.where("phone", "==", phone).limit(1).get();
    if (!duplicateQuery.empty) {
      console.log(`Lead with phone ${phone} already exists for agent ${agent_id}. Skipping.`);
      return res.status(200).json({ status: "skipped", message: "Duplicate lead detected." });
    }

    const newLead = {
      clientName: clientName,
      phone: phone,
      email: email,
      property: property,
      status: "new",
      lastTag: "MagicBricks",
      followUpDate: "none",
      lastNote: "Auto-imported via MagicBricks Webhook Integration.",
      isActive: true,
      callDuration: "—",
      createdAt: new Date().toISOString(),
      callsCount: 0,
      source: "MagicBricks",
    };

    const docRef = await leadsRef.add(newLead);
    console.log(`Successfully imported MagicBricks webhook lead: ${docRef.id} for agent ${agent_id}`);

    return res.status(201).json({ status: "success", leadId: docRef.id });
  } catch (err) {
    console.error("Error processing MagicBricks webhook:", err);
    return res.status(500).json({ error: err.message || "Internal Server Error" });
  }
});

