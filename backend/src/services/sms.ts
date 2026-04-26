import { env } from "../core/config";

type SmsDeliveryStatus = "sent" | "skipped" | "unavailable" | "failed";

export type EmergencySmsResult = {
  status: SmsDeliveryStatus;
  provider: "twilio" | "infobip" | "none";
  error?: string;
};

function normalizePhoneNumber(phone: string): string {
  const raw = phone.trim();
  if (!raw) {
    return "";
  }

  const compact = raw.replace(/[\s\-().]/g, "");
  if (!compact) {
    return "";
  }

  if (compact.startsWith("+")) {
    return compact;
  }

  if (compact.startsWith("00")) {
    return `+${compact.slice(2)}`;
  }

  const defaultCountryCode = env.SMS_DEFAULT_COUNTRY_CODE.startsWith("+")
    ? env.SMS_DEFAULT_COUNTRY_CODE
    : `+${env.SMS_DEFAULT_COUNTRY_CODE}`;

  const digitsOnly = compact.replace(/\D/g, "");
  if (!digitsOnly) {
    return "";
  }

  if (digitsOnly.startsWith("0")) {
    return `${defaultCountryCode}${digitsOnly.slice(1)}`;
  }

  return `${defaultCountryCode}${digitsOnly}`;
}

async function sendViaInfobip(phone: string, message: string): Promise<EmergencySmsResult> {
  const { INFOBIP_API_KEY, INFOBIP_BASE_URL, INFOBIP_SENDER } = env;

  console.log("[SMS] Infobip config:", { apiKey: INFOBIP_API_KEY, baseUrl: INFOBIP_BASE_URL, sender: INFOBIP_SENDER });

  if (!INFOBIP_API_KEY || !INFOBIP_BASE_URL || !INFOBIP_SENDER) {
    return { status: "unavailable", provider: "infobip" };
  }

  console.log("[SMS] Infobip sending to:", phone, "from:", INFOBIP_SENDER);

  const response = await fetch(
    `${INFOBIP_BASE_URL}/sms/3/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `App ${INFOBIP_API_KEY}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        messages: [
          {
            destinations: [
              {
                to: phone,
              },
            ],
            from: INFOBIP_SENDER,
            content: {
              text: `Safety Net SOS: ${message}`,
            },
          },
        ],
      }),
    },
  );

  const responseText = await response.text();
  console.log("[SMS] Infobip response:", response.status, responseText);

  if (!response.ok) {
    return {
      status: "failed",
      provider: "infobip",
      error: `Infobip failed (${response.status}): ${responseText.slice(0, 200)}`,
    };
  }

  return { status: "sent", provider: "infobip" };
}

async function sendViaTwilio(phone: string, message: string): Promise<EmergencySmsResult> {
  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER } = env;

  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_FROM_NUMBER) {
    return { status: "unavailable", provider: "twilio" };
  }

  console.log("[SMS] Twilio sending to:", phone, "from:", TWILIO_FROM_NUMBER);

  const body = new URLSearchParams({
    To: phone,
    From: TWILIO_FROM_NUMBER,
    Body: `Safety Net SOS: ${message}`,
  });

  const authToken = Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString("base64");
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${authToken}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  );

  const responseText = await response.text();
  console.log("[SMS] Twilio response:", response.status, responseText);
  if (!response.ok) {
    return {
      status: "failed",
      provider: "twilio",
      error: `Twilio failed (${response.status}): ${responseText.slice(0, 200)}`,
    };
  }

  return { status: "sent", provider: "twilio" };
}

export async function sendEmergencySms(input: {
  phone: string;
  message: string;
}): Promise<EmergencySmsResult> {
  const phone = normalizePhoneNumber(input.phone);
  console.log("[SMS] Input phone:", input.phone, "-> normalized:", phone);
  if (!phone) {
    console.log("[SMS] Phone normalized to empty, skipping");
    return { status: "skipped", provider: "none" };
  }

  const hasInfobip = env.INFOBIP_API_KEY && env.INFOBIP_BASE_URL && env.INFOBIP_SENDER;
  const hasTwilio = env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM_NUMBER;

  console.log("[SMS] hasInfobip:", hasInfobip, "hasTwilio:", hasTwilio);

  if (hasInfobip) {
    return sendViaInfobip(phone, input.message);
  }

  if (hasTwilio) {
    return sendViaTwilio(phone, input.message);
  }

  return { status: "unavailable", provider: "none" };
}