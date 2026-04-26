import { config as loadEnv } from "dotenv";
import { z } from "zod";

loadEnv();

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  SQLITE_DB_PATH: z.string().min(1).default("../database/assets/health_app.db"),
  TWILIO_ACCOUNT_SID: z.string().min(1).optional(),
  TWILIO_AUTH_TOKEN: z.string().min(1).optional(),
  TWILIO_FROM_NUMBER: z.string().min(1).optional(),
  INFOBIP_API_KEY: z.string().min(1).optional(),
  INFOBIP_BASE_URL: z.string().min(1).optional(),
  INFOBIP_SENDER: z.string().min(1).optional(),
  SMS_DEFAULT_COUNTRY_CODE: z.string().min(1).default("+40"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("Invalid environment configuration", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
